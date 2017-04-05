classdef CPRLabelTracker < LabelTracker
  
  properties (Constant,Hidden)
    TRAINEDTRACKER_SAVEPROPS = { ...
      'sPrm' ...
      'trnDataDownSamp' 'trnDataFFDThresh' 'trnDataTblP' 'trnDataTblPTS' ...
      'trnResH0' 'trnResIPt' 'trnResRC'};
    TRACKRES_SAVEPROPS = {'trkP' 'trkPFull' 'trkPTS' 'trkPMD' 'trkPiPt'};
    
    DEFAULT_PARAMETER_FILE = lclInitDefaultParameterFile();
  end
  
  %% Params
  properties
    sPrm % full parameter struct
  end
  
  %% Data
  properties
    
    % Cached/working dataset. Contains all I/p/md for frames that have been
    % seen before by the tracker.
    % - Can be used for both training and tracking.
    % - Current training frames stored in data.iTrn
    % - Current test/track frames stored in data.iTst
    %
    % - All frames have an image, but need not have labels (p).
    % - If applicable, all frames are HE-ed the same way.
    % - If applicable, all frames are PP-ed the same way.
    data
    
    % Timestamp, last data modification (for any reason)
    dataTS
  end
  
  %% Training Data Selection
  properties (SetObservable,SetAccess=private)
    trnDataDownSamp = false; % scalar logical. 
  end
  properties
    % Furthest-first distance threshold for training data.
    trnDataFFDThresh
    
    % Currently selected training data (includes updates/additions)
    trnDataTblP % cols: 
                % .mov. unique ID for movie; standardized path
                % .frm. frame number. The combo mov|frm should be a unique key for the table.
                % .p. [1xD] labeled shape
                % .tfocc. [1xd] occluded flags
                % .pTS. [1xd] timestamps for .p.
    trnDataTblPTS % [size(trnDataTblP,1)x1] timestamps for when rows of trnDataTblP were added to CPRLabelTracker
  end
  
  % Notes on Tables: .trnDataTblP, trkPMD, .data.MD.
  %
  % These are all MFTables (Movie-frame tables) where .mov is computed as
  % FSPath.standardPath(lObj.movieFilesAll(...)). That is, .mov has
  % unreplaced macros, and is not localized/platformized. Stored in this
  % way, .mov is well-suited to serve as a unique movie ID in the tables,
  % and can be serialized/loaded and concretized to the runtime platform as
  % appropriate.
  %
  % Multiview data: movie IDs computed as above are delimiter-concatenated
  % to form a single unique ID for each movieset.
  
  %% Train/Track
  properties
    
    % Training state -- set during .train()
    trnResH0 % image hist used for current training results (trnResRC)
    trnResIPt % TODO doc me. Basically like .trkPiPt.
    trnResRC % [1xnView] RegressorCascade.
    
    % Tracking state -- set during .track()
    % Note: trkD here can be less than the full/model D if some pts are
    % omitted from tracking
    trkP % [NTst trkD T+1] reduced/pruned tracked shapes
    trkPFull % [NTst RT trkD T+1] Tracked shapes full data
    trkPTS % [NTstx1] timestamp for trkP*
    trkPMD % [NTst <ncols>] table. MFTable (no other cols) for trkP*
    trkPiPt % [npttrk] indices into 1:obj.npts, tracked points. npttrk=trkD*d.
    
    % View/presentation
    xyPrdCurrMovie; % [npts d nfrm] predicted labels for current Labeler movie
    xyPrdCurrMovieIsInterp; % [nfrm] logical vec indicating whether xyPrdCurrMovie(:,:,i) is interpolated
    hXYPrdRed; % [npts] plot handles for 'reduced' tracking results, current frame
    xyVizPlotArgs; % cell array of args for regular tracking viz
    xyVizPlotArgsInterp; % cell array of args for interpolated tracking viz
  end
  properties (Dependent)
    nPts % number of label points 
    nPtsTrk % number of tracked label points; will be <= nPts. See .trkPiPt.
    
    hasTrained
  end
  
  %% Dep prop getters
  methods
    function v = get.nPts(obj)
      v = obj.lObj.nLabelPoints;
    end
    function v = get.nPtsTrk(obj)
      v = numel(obj.trkPiPt);
    end
    function v = get.hasTrained(obj)
      v = ~isempty(obj.trnResRC) && any([obj.trnResRC.hasTrained]);
    end
  end
  
  %% Ctor/Dtor
  methods
    
    function obj = CPRLabelTracker(lObj)
      obj@LabelTracker(lObj);
    end
    
    function delete(obj)
      deleteValidHandles(obj.hXYPrdRed);
      obj.hXYPrdRed = [];
    end
    
  end
  
  %% Data
  methods
    
    % AL 20160531 Data and timestamps
    %
    % - All labels are timestamped in the labeler (each pt has its own ts).-
    % This is done at manual-label-time (eg clicktime). The .pTS field in
    % MD tables contains this ts.
    % - .trnDataTblPTS contains timestamps labeling rows of .trnDataTblP.
    % These timestamps label when labels are accepted into the training
    % set.
    %
    % It is necessary to track this timestamp b/c the selection of a 
    % training set represents a filtering of labeled data, ie some labeled 
    % data will not be included. Once a training data set is selected,
    % moving forward we may want to find new labels made since the time of
    % that training set selection etc.
    %
    % - The RegressorCascade in .trnResRC has its own timestamps for
    % training time and so on.
    
    %#MV
    function tblP = getTblPLbledRecent(obj)
      % tblP: labeled data from Labeler that is more recent than anything 
      % in .trnDataTblPTS
      
      tblP = obj.getTblPLbled();
      maxTS = max(tblP.pTS,[],2);
      maxTDTS = max([obj.trnDataTblPTS(:);-inf]);
      tf = maxTS > maxTDTS;
      tblP = tblP(tf,:);
    end 
      
    %#MV
    function [tblPnew,tblPupdate] = tblPDiffData(obj,tblP)
      td = obj.data;
      tbl0 = td.MD;
      tbl0.p = td.pGT;
      [tblPnew,tblPupdate] = MFTable.tblPDiff(tbl0,tblP);
    end
    
    %#MV
    function [tblPnew,tblPupdate,idxTrnDataTblP] = tblPDiffTrnData(obj,tblP)
      [tblPnew,tblPupdate,idxTrnDataTblP] = MFTable.tblPDiff(obj.trnDataTblP,tblP);
    end
    
    %#MV
    function initData(obj)
      % Initialize .data*
      
      I = cell(0,1);
      tblP = struct2table(struct('mov',cell(0,1),'frm',[],'p',[],'tfocc',[]));
      
      obj.data = CPRData(I,tblP);
      obj.dataTS = now;
    end
    
    %#MV
    function updateData(obj,tblP)
      % Update .data to include tblP
      
      [tblPnew,tblPupdate] = obj.tblPDiffData(tblP);
      hWB = waitbar(0);
      hTxt = findall(hWB,'type','text');
      hTxt.Interpreter = 'none';
      obj.updateDataRaw(tblPnew,tblPupdate,'hWaitBar',hWB);
      delete(hWB);
    end
    
    %#MV
    function updateDataRaw(obj,tblPNew,tblPupdate,varargin)
      % Incremental data update
      %
      % * Rows appended and pGT/tfocc updated; but other information
      % untouched
      % * PreProc parameters must be same as existing
      % * histeq (if enabled in preproc params) will always use .trnResH0.
      % See "Hist Eq Notes" below
      %
      % QUESTION: why is pTS not updated?
      %
      % tblPNew: new rows
      % tblPupdate: updated rows (rows with updated pGT/tfocc)
      %
      % sets .data, .dataTS      
      
      [hWB] = myparse(varargin,...
        'hWaitBar',[]);
      
      if isempty(obj.sPrm)
        error('CPRLabelTracker:param','Please specify tracking parameters.');
      end
      
      prmpp = obj.sPrm.PreProc;
      dataCurr = obj.data;
      tblMFcurr = dataCurr.MD(:,{'mov' 'frm'});
      
      if prmpp.histeq
        assert(dataCurr.N==0 || isequal(dataCurr.H0,obj.trnResH0));
        assert(obj.lObj.nview==1,...
          'Histogram Equalization currently unsupported for multiview tracking.');
      end
      if ~isempty(prmpp.channelsFcn)
        assert(obj.lObj.nview==1,...
          'Channels preprocessing currently unsupported for multiview tracking.');
      end
      
      %%% EXISTING ROWS -- just update pGT and tfocc. Existing images are
      %%% OK and already histeq'ed correctly
      nUpdate = size(tblPupdate,1);
      if nUpdate>0 % AL 20160413 Shouldn't need to special-case, MATLAB table indexing API may not be polished
        fprintf(1,'Updating labels for %d rows...\n',nUpdate);
        tblMFupdate = tblPupdate(:,{'mov' 'frm'});
        [tf,loc] = ismember(tblMFupdate,tblMFcurr);
        assert(all(tf));
        dataCurr.MD{loc,'tfocc'} = tblPupdate.tfocc; % AL 20160413 throws if nUpdate==0
        dataCurr.pGT(loc,:) = tblPupdate.p;
      end
      
      %%% NEW ROWS -- read images + PP
      tblMFnew = tblPNew(:,{'mov' 'frm'});
      assert(~any(ismember(tblMFnew,tblMFcurr)));
      tblMFnewConcrete = tblMFnew;
      if obj.lObj.isMultiView && ~isempty(tblMFnewConcrete.mov)
        tmp = cellfun(@MFTable.unpackMultiMovieID,tblMFnewConcrete.mov,'uni',0);
        tblMFnewConcrete.mov = cat(1,tmp{:});
      end
      tblMFnewConcrete.mov = FSPath.fullyLocalizeStandardize(...
        tblMFnewConcrete.mov,obj.lObj.projMacros);
      % tblMFnewConcerete.mov is now [NxnView] 
      nNew = size(tblPNew,1);
      if nNew>0
        fprintf(1,'Adding %d new rows to data...\n',nNew);
        I = CPRData.getFrames(tblMFnewConcrete);
        dataNew = CPRData(I,tblPNew);
        if prmpp.histeq
          H0 = obj.trnResH0;
          assert(~isempty(H0),'H0 unavailable for histeq/preprocessing.');
          gHE = categorical(dataNew.MD.mov);
          dataNew.histEq('g',gHE,'H0',H0,'hWaitBar',hWB);
          assert(isequal(dataNew.H0,H0));
          if dataCurr.N==0
            dataCurr.H0 = H0;
            % dataCurr.H0, dataNew.H0 need to match for append()
          end
        end
        if ~isempty(prmpp.channelsFcn)
          feval(prmpp.channelsFcn,dataNew,'hWaitBar',hWB);
          assert(~isempty(dataNew.IppInfo),...
            'Preprocessing channelsFcn did not set .IppInfo.');
          if isempty(dataCurr.IppInfo)
            assert(dataCurr.N==0,'Ippinfo can be empty only for empty/new data.');
            dataCurr.IppInfo = dataNew.IppInfo;
          end
        end
        
        dataCurr.append(dataNew);
      end
      
      if nUpdate>0 || nNew>0
        %obj.data = dataCurr;
        assert(obj.data==dataCurr); % handles
        obj.dataTS = now;
      else
        warningNoTrace('CPRLabelTracker:data','Nothing to update in data.');
      end
    end
    
    % Hist Eq Notes
    %
    % We imagine that Labeler maintains or can compute a "typical" image
    % histogram H0 representative of all movies in the current project. At
    % the moment it does by sampling frames at intervals (weighting all
    % frames equally regardless of movie), but this is an impl detail to
    % CPRLabelTracker.
    %
    % CPRLabelTracker maintains its own H0 (.trnResH0) which is the image
    % histogram used during training of the current RegressorCascade 
    % (.trnResRC). All training images input into the current RC were
    % preprocessed with this H0 (if histeq preprocessing was enabled). All
    % images-to-be-tracked should be similarly preprocessed.
    %
    % .trnResH0 is set at retrain- (fulltraining-) time. It is not updated
    % during tracking, or during incremental trains. Users should
    % periodically retrain fully, to sync .trnResH0 with the Labeler's H0.
    % Note that the set of movies in the Labeler project may have changed
    % considerably (eg if many new movies were added) since the last full
    % retrain. Thus this periodic (re)syncing of .trnResH0 with Labeler.H0
    % is important.
    %
    % When training results are cleared (trnResInit), we currently clear
    % .trnResH0 as well.
    %
    % A final detail, note that .data has its own .H0 for historical
    % reasons. This represents the H0 used for histeq-ing .data. This
    % should always coincide with .trnResH0, except that trnResInit() can
    % clear .trnResH0 and leave .data.H0 intact. 
    % 
    % SUMMARY MAIN OPERATIONS
    % retrain: this resets trnH0 to match Labeler.H0; .data.H0 is also
    % forced to match (.data is initially cleared if it had a different
    % .H0)
    % inctrain: .trnH0 untouched, so trnH0 may differ from Labeler.H0.
    % .data.H0 must match .trnH0.
    % track: same as inctrain.

  end
  
  %% Training Data Selection
  methods
    
    %#MV
    function trnDataInit(obj)
      obj.trnDataDownSamp = false;
      obj.trnDataFFDThresh = nan;
      obj.trnDataTblP = struct2table(struct('mov',cell(0,1),...
        'frm',[],'p',[],'tfocc',[],'pTS',[]));
      obj.trnDataTblPTS = -inf(0,1);
    end
    
    function trnDataUseAll(obj)
      if obj.trnDataDownSamp
        if obj.hasTrained
          warningNoTrace('CPRLabelTracker:clear','Clearing existing tracker.');
        end
        obj.trnDataInit();
        obj.trnResInit();
        obj.trackResInit();
        obj.vizInit();
      end
    end
    
    %#MV
    function trnDataSelect(obj)
      % Furthest-first selection of training data.
      %
      % Based on user interaction, .trnDataFFDThresh, .trnDataTblP* are set.
      % For .trnDataTblP*, this is a fresh reset, not an update.
      
      obj.trnResInit();
      obj.trackResInit();
      obj.vizInit();
        
      tblP = obj.getTblPLbled(); % start with all labeled data
      [grps,ffd,ffdiTrl] = CPRData.ffTrnSet(tblP,[]);
      
      mov = categorical(tblP.mov); % multiview data: mov and related are multimov IDs
      movUn = categories(mov);
      nMovUn = numel(movUn);
      movUnCnt = countcats(mov);
      n = size(tblP,1);
      
      hFig = CPRData.ffTrnSetSelect(tblP,grps,ffd,ffdiTrl,...
        'cbkFcn',@(xSel,ySel)nst(xSel,ySel));
      
      function nst(~,ySel)
        % xSel/ySel: (x,y) on ffd plot nearest to user click (see
        % CPRData.ffTrnSetSelect)
        
        ffdThresh = ySel;
        assert(isscalar(ffd) && isscalar(ffdiTrl));
        tfSel = ffd{1}>=ffdThresh;
        iSel = ffdiTrl{1}(tfSel);
        nSel = numel(iSel);
        
        tblPSel = tblP(iSel,:);
        movSel = categorical(tblPSel.mov);
        movUnSelCnt = arrayfun(@(x)nnz(movSel==x),movUn);
        for iMov = 1:nMovUn
          fprintf(1,'%s: nSel/nTot=%d/%d (%d%%)\n',char(movUn(iMov)),...
            movUnSelCnt(iMov),movUnCnt(iMov),round(movUnSelCnt(iMov)/movUnCnt(iMov)*100));
        end
        fprintf(1,'Grand total of %d/%d (%d%%) shapes selected for training.\n',...
          nSel,n,round(nSel/n*100));
        
        res = input('Accept this selection (y/n/c)?','s');
        if isempty(res)
          res = 'c';
        end
        switch lower(res)
          case 'y'
            obj.trnDataDownSamp = true;
            obj.trnDataFFDThresh = ffdThresh;
            obj.trnDataTblP = tblPSel;
            obj.trnDataTblPTS = now*ones(size(tblPSel,1),1);
          case 'n'
            % none
          case 'c'
            delete(hFig);
        end
      end
    end
    
  end
  
  %% TrainRes
  methods
    function trnResInit(obj)
      if isempty(obj.sPrm)
        obj.trnResRC = [];
      else
        nview = obj.lObj.nview;
        sPrmUse = obj.sPrm;
        %sPrmUse.Model.nfids = sPrmUse.Model.nfids/nview;
        sPrmUse.Model.nviews = 1;
        for i=1:nview
          rc(1,i) = RegressorCascade(sPrmUse); %#ok<AGROW>
        end
        obj.trnResRC = rc;
      end
      obj.trnResIPt = [];
      obj.trnResH0 = [];
    end
  end
  
  %% TrackRes
  methods

    %#MV
    function [trkpos,trkposTS,trkposFull,tfHasRes] = getTrackResRaw(obj,iMov)
      % Get tracking results for movie(set) iMov.
      %
      % iMov: scalar movie(set) index
      % 
      % trkpos: [nptstrk x d x nfrm(iMov)]. Tracking results for iMov. 
      %  IMPORTANT: first dim is nptstrk=numel(.trkPiPt), NOT obj.npts. If
      %  movies in a movieset have differing numbers of frames, then nfrm
      %  will equal the minimum number of frames across the movieset.
      % trkposTS: [nptstrk x nfrm(iMov)]. Timestamps for trkpos.
      % trkposFull: [nptstrk x d x nRep x nfrm(iMov)]. 4d results.
      % tfHasRes: if true, nontrivial tracking results returned
      
      lObj = obj.lObj;
      movNameID = FSPath.standardPath(lObj.movieFilesAll(iMov,:));
      movNameID = MFTable.formMultiMovieID(movNameID);
      nfrms = lObj.movieInfoAll{iMov}.nframes; % For moviesets with movies with differing # of frames, this should be the common minimum

      pTrk = obj.trkP(:,:,end); % [NTst x D]
      [NTrk,DTrk] = size(pTrk);
      trkMD = obj.trkPMD;
      iPtTrk = obj.trkPiPt;
      nPtTrk = numel(iPtTrk);
      d = 2;
      assert(size(trkMD,1)==NTrk);
      assert(nPtTrk*d==DTrk);
          
      if isempty(obj.trkPFull)
        pTrkFull = nan(NTrk,0,DTrk);
      else
        pTrkFull = obj.trkPFull(:,:,:,end);
      end
      nRep = size(pTrkFull,2);
      szassert(pTrkFull,[NTrk nRep DTrk]);
      
      assert(numel(obj.trkPTS)==NTrk);

      trkpos = nan(nPtTrk,d,nfrms);
      trkposTS = -inf(nPtTrk,nfrms);
      trkposFull = nan(nPtTrk,d,nRep,nfrms);

      if isempty(obj.trkPTS) % proxy for no tracking results etc
        tfHasRes = false;
      else
        tfCurrMov = strcmp(trkMD.mov,movNameID); % these rows of trkMD are for the movie(set) iMov
        nCurrMov = nnz(tfCurrMov);
        xyTrkCurrMov = reshape(pTrk(tfCurrMov,:)',nPtTrk,d,nCurrMov);        
        frmCurrMov = trkMD.frm(tfCurrMov);
        trkpos(:,:,frmCurrMov) = xyTrkCurrMov;
        tmpTS = obj.trkPTS(tfCurrMov);
        trkposTS(:,frmCurrMov) = repmat(tmpTS(:)',nPtTrk,1);
        
        xyTrkFullCurrMov = pTrkFull(tfCurrMov,:,:); % [nCurrMov nRep D]
        xyTrkFullCurrMov = permute(xyTrkFullCurrMov,[3 2 1]);
        xyTrkFullCurrMov = reshape(xyTrkFullCurrMov,[nPtTrk d nRep nCurrMov]);
        trkposFull(:,:,:,frmCurrMov) = xyTrkFullCurrMov;
        
        tfHasRes = (nCurrMov>0);
      end
      
    end
          
  end
  
  %% LabelTracker overloads
  methods
    
    %#MV
    function initHook(obj)
      obj.initData();
      obj.trnDataInit();
      obj.trnResInit();
      obj.trackResInit();
      obj.vizInit();
    end
    
    %#MV
    function setParamHook(obj)
      sNew = obj.readParamFileYaml();
      sNew = CPRLabelTracker.modernizeParams(sNew);
      obj.setParamContentsSmart(sNew);
    end
    
    %#MV
    function setParamContentsSmart(obj,sNew)
      % Set parameter contents (.sPrm), looking at what top-level fields 
      % have changed and clearing obj state appropriately.
      
      sOld = obj.sPrm;
      obj.sPrm = sNew; % set this now so eg trnResInit() can use
      
      if isempty(sOld) || isempty(sNew)
        obj.initData();
        obj.trnDataInit();
        obj.trnResInit();
        obj.trackResInit();
        obj.vizInit();
      else % Both sOld, sNew nonempty
        if sNew.Model.nviews~=obj.lObj.nview
          error('CPRLabelTracker:nviews',...
            'Number of views in parameters.Model (%d) does not match number of views in project (%d).',...
            sNew.Model.nviews,obj.lObj.nview);
        end
        if sNew.Model.nfids~=obj.lObj.nPhysPoints
          error('CPRLabelTracker:npts',...
            'Number of points in parameters.Model (%d) does not match number of physical points in project (%d).',...
            sNew.Model.nfids,obj.lObj.nPhysPoints);
        end
        
        if isempty(sOld.Model.nviews)
          sOld.Model.nviews = 1;
          % set this to enable comparisons below
        end
      
        % Figure out what changed
        flds = fieldnames(sOld);
        tfunchanged = struct();
        for f=flds(:)',f=f{1}; %#ok<FXSET>
          tfunchanged.(f) = isequaln(sOld.(f),sNew.(f));
        end
        
        % data
        modelPPUC = tfunchanged.Model && tfunchanged.PreProc;
        if ~modelPPUC
          fprintf(2,'Parameter change: CPRLabelTracker data cleared.\n');
          obj.initData();
        end
        
        % trainingdata
        if ~modelPPUC
          fprintf(2,'Parameter change: CPRLabelTracker training data selection cleared.\n');
          obj.trnDataInit();
        end
      
        % trnRes
        modelPPRegFtrTrnInitUC = modelPPUC && tfunchanged.Reg ...
            && tfunchanged.Ftr && tfunchanged.TrainInit;
        if ~modelPPRegFtrTrnInitUC
          fprintf(2,'Parameter change: CPRLabelTracker regressor casacade cleared.\n');
          obj.trnResInit();
        end
      
        % trkP
        if ~(modelPPRegFtrTrnInitUC && tfunchanged.TestInit && tfunchanged.Prune)
          fprintf(2,'Parameter change: CPRLabelTracker tracking results cleared.\n');
          obj.trackResInit();
          obj.vizInit();
        end
      end      
    end
        
    %#MV
    function retrain(obj,varargin)
      % Full train 
      % 
      % Sets .trnRes*
      
      updateTrnData = myparse(varargin,...
        'updateTrnData',true ... % if false, don't check for new/recent Labeler labels. Used only when .trnDataDownSamp is true.
        );
      
      prm = obj.sPrm;
      if isempty(prm)
        error('CPRLabelTracker:param','Please specify tracking parameters.');
      end
       
      if obj.trnDataDownSamp
        if updateTrnData
          % first, update the TrnData with any new labels
          tblPNew = obj.getTblPLbledRecent();
          [tblPNewTD,tblPUpdateTD,idxTrnDataTblP] = obj.tblPDiffTrnData(tblPNew);
          if ~isempty(idxTrnDataTblP) % AL 20160912: conditional should not be necessary, MATLAB API bug
            obj.trnDataTblP(idxTrnDataTblP,:) = tblPUpdateTD;
          end
          obj.trnDataTblP = [obj.trnDataTblP; tblPNewTD];
          nowtime = now();
          nNewRows = size(tblPNewTD,1);
          obj.trnDataTblPTS(idxTrnDataTblP) = nowtime;
          obj.trnDataTblPTS = [obj.trnDataTblPTS; nowtime*ones(nNewRows,1)];
          fprintf('Updated training data with new labels: %d updated rows, %d new rows.\n',...
            size(tblPUpdateTD,1),nNewRows);
        end
        tblPTrn = obj.trnDataTblP;
      else
        % use all labeled data
        tblPTrn = obj.getTblPLbled();
        
        assert(isnan(obj.trnDataFFDThresh));
        % still set .trnDataTblP, .trnDataTblPTS to enable incremental
        % training
        obj.trnDataTblP = tblPTrn;
        nowtime = now();
        obj.trnDataTblPTS = nowtime*ones(size(tblPTrn,1),1);
      end
      
      if isempty(tblPTrn)
        error('CPRLabelTracker:noTrnData','No training data set.');
      else
        fprintf(1,'Training with %d rows.\n',size(tblPTrn,1));
      end
      tblPTrn(:,'pTS') = [];
      
      % update .trnResH0; clear .data if necessary (if .trnResH0 is
      % out-of-date)
      if prm.PreProc.histeq
        assert(obj.lObj.nview==1,...
          'Histogram Equalization currently unsupported for multiview projects.');
        
        nFrmSampH0 = prm.PreProc.histeqH0NumFrames;
        H0 = obj.lObj.movieEstimateImHist(nFrmSampH0);
        
        if ~isequal(obj.data.H0,obj.trnResH0)
          assert(obj.data.N==0 || ... % empty .data
                 isempty(obj.trnResH0),... % empty .trnResH0 (eg trnResInit() called)
                 '.data.H0 differs from .trnResH0');
        end
        if ~isequal(H0,obj.data.H0)
          obj.initData();
        end
        if ~isequal(H0,obj.trnResH0)
          obj.trnResH0 = H0;
        end
      else
        assert(isempty(obj.data.H0));
        assert(isempty(obj.trnResH0));
      end
      
      obj.updateData(tblPTrn);
      
      d = obj.data;
      tblMF = d.MD(:,{'mov' 'frm'});
      tblTrnMF = tblPTrn(:,{'mov','frm'});
      tf = ismember(tblMF,tblTrnMF);
      assert(nnz(tf)==size(tblTrnMF,1));
      d.iTrn = find(tf);
      
      fprintf(1,'Training data summary:\n');
      d.summarize('mov',d.iTrn);
      
      [Is,nChan] = d.getCombinedIs(d.iTrn);
      prm.Ftr.nChn = nChan;
      
      iPt = prm.TrainInit.iPt;
      nfids = prm.Model.nfids;
      nviews = prm.Model.nviews;
      assert(prm.Model.d==2);
      nfidsInTD = size(d.pGT,2)/prm.Model.d;
      if isempty(iPt)
        assert(nfidsInTD==nfids*nviews);
        iPt = 1:nfidsInTD;
      else
        assert(obj.lObj.nview==1,'TrainInit.iPt specification currently unsupported for multiview projects.');
      end
      iPGT = [iPt iPt+nfidsInTD];
      fprintf(1,'iPGT: %s\n',mat2str(iPGT));
      pTrn = d.pGTTrn(:,iPGT);
      % pTrn col order is: [iPGT(1)_x iPGT(2)_x ... iPGT(end)_x iPGT(1)_y ... iPGT(end)_y]
      
      nView = obj.lObj.nview;
      if nView==1 % doesn't need its own branch, just leaving old path
        obj.trnResRC.trainWithRandInit(Is,d.bboxesTrn,pTrn);
      else
        assert(size(Is,2)==nView);
        assert(size(pTrn,2)==obj.lObj.nPhysPoints*nView*prm.Model.d); 
        assert(nfidsInTD==obj.lObj.nPhysPoints*nView);
        % col order of pTrn should be:
        % [p1v1_x p2v1_x .. pkv1_x p1v2_x .. pkv2_x .. pkvW_x
        nPhysPoints = obj.lObj.nPhysPoints;
        for iView=1:nView
          IsVw = Is(:,iView);
          bbVw = CPRData.getBboxes2D(IsVw);
          iPtVw = (1:nPhysPoints)+(iView-1)*nPhysPoints;
          assert(isequal(iPtVw(:),find(obj.lObj.labeledposIPt2View==iView)));
          pTrnVw = pTrn(:,[iPtVw iPtVw+nfidsInTD]);
          
          obj.trnResRC(iView).trainWithRandInit(IsVw,bbVw,pTrnVw);
        end
      end
      obj.trnResIPt = iPt;
    end
    
    function train(obj,varargin)
      % Incremental trainupdate using labels newer than .trnDataTblPTS

      prm = obj.sPrm;
      if isempty(prm)
        error('CPRLabelTracker:param','Please specify tracking parameters.');
      end
        
      % figure out if we want an incremental train or full retrain
      rc = obj.trnResRC;
      if any(~[rc.hasTrained])
        obj.retrain(varargin{:});
        return;
      end        
            
      assert(obj.lObj.nview==1,...
        'Incremental training currently unsupported for multiview projects.');
      
      tblPNew = obj.getTblPLbledRecent();
      
      if isempty(tblPNew)
        msgbox('Trained tracker is up-to-date with labels.','Tracker up-to-date');
        return;
      end
      
      %%% do incremental train
      
      % update the TrnData
      [tblPNewTD,tblPUpdateTD,idxTrnDataTblP] = obj.tblPDiffTrnData(tblPNew);
      if ~isempty(idxTrnDataTblP) % AL: conditional should not be necessary, MATLAB API bug
        obj.trnDataTblP(idxTrnDataTblP,:) = tblPUpdateTD;
      end
      obj.trnDataTblP = [obj.trnDataTblP; tblPNewTD];
      nowtime = now();
      obj.trnDataTblPTS(idxTrnDataTblP) = nowtime;
      obj.trnDataTblPTS = [obj.trnDataTblPTS; nowtime*ones(size(tblPNewTD,1),1)];
      
      % print out diagnostics on when training occurred etc
      iTL = rc.trnLogMostRecentTrain();
      tsFullTrn = rc.trnLog(iTL).ts;
      fprintf('Most recent full train at %s\n',datestr(tsFullTrn,'mmm-dd-yyyy HH:MM:SS'));
      obj.trainPrintDiagnostics(iTL);
     
      tblPNew(:,'pTS') = [];
      obj.updateData(tblPNew);
      
      % set iTrn and summarize
      d = obj.data;
      tblMF = d.MD(:,{'mov' 'frm'});
      tblNewMF = tblPNew(:,{'mov','frm'});
      tf = ismember(tblMF,tblNewMF);
      assert(nnz(tf)==size(tblNewMF,1));
      d.iTrn = find(tf);
      
      fprintf(1,'Training data summary:\n');
      d.summarize('mov',d.iTrn);
      
      % Call rc.train with 'update', true 
      [Is,nChan] = d.getCombinedIs(d.iTrn);
      prm.Ftr.nChn = nChan;
            
      iPt = prm.TrainInit.iPt;
      nfids = prm.Model.nfids;
      assert(prm.Model.d==2);
      nfidsInTD = size(d.pGT,2)/prm.Model.d;
      if isempty(iPt)
        assert(nfidsInTD==nfids);
        iPt = 1:nfidsInTD;
      end
      iPGT = [iPt iPt+nfidsInTD];
      fprintf(1,'iPGT: %s\n',mat2str(iPGT));
      
      pTrn = d.pGTTrn(:,iPGT);

      rc = obj.trnResRC;
      rc.trainWithRandInit(Is,d.bboxesTrn,pTrn,'update',true,'initpGTNTrn',true);

      %obj.trnResTS = now;
      %obj.trnResPallMD = d.MD;
      assert(isequal(obj.trnResIPt,iPt));
    end
    
    %#MV
    function trainPrintDiagnostics(obj,iTL)
      % iTL: Index into .trnLog at which to start
      
      rc = obj.trnResRC(1);
      tsFullTrn = rc.trnLog(iTL).ts;

      nTL = numel(rc.trnLog);
      tsTrnDataUn = unique(obj.trnDataTblPTS);
      tsTrnDataUn = tsTrnDataUn(tsTrnDataUn>=tsFullTrn); % trn data updates after most recent fulltrain
      tsTrnDataUn = sort(tsTrnDataUn);
      ntsTrnData = numel(tsTrnDataUn);
      itsTD = 0;
      while iTL<nTL || itsTD<ntsTrnData
        if iTL==nTL
          action = 'trnData';
        elseif itsTD==ntsTrnData
          action = 'trnLog';
        elseif rc.trnLog(iTL+1).ts<tsTrnDataUn(itsTD+1)
          action = 'trnLog';
        else
          action = 'trnData';
        end
        
        switch action
          case 'trnLog'
            fprintf('%s at %s\n',rc.trnLog(iTL+1).action,...
              datestr(rc.trnLog(iTL+1).ts,'mmm-dd-yyyy HH:MM:SS'));
            iTL = iTL+1;
          case 'trnData'
            ntmp = nnz(obj.trnDataTblPTS==tsTrnDataUn(itsTD+1));
            fprintf('%d labels added to training data at %s\n',ntmp,...
              datestr(tsTrnDataUn(itsTD+1),'mmm-dd-yyyy HH:MM:SS'));
            itsTD = itsTD+1;
        end
      end
    end
    
    % MOVE THIS METHOD BELOW
    function loadTrackResMerge(obj,fname)
      % Load tracking results from fname, merging into existing results
      
      assert(false,'Check me, updated metadata tables 20161027.');
      
%       tr = load(fname);
%       if ~isempty(obj.paramFile) && ~strcmp(tr.paramFile,obj.paramFile)
%         warningNoTrace('CPRLabelTracker:paramFile',...
%           'Tracking results generated using parameter file ''%s'', which differs from current file ''%s''.',...
%           tr.paramFile,obj.paramFile);
%       end
%       
%       if ~isempty(obj.trkP) % training results exist
%         
%         if ~isequal(obj.trkPiPt,tr.trkPiPt)
%           error('CPRLabelTracker:trkPiPt','''trkPiPt'' differs in tracked results to be loaded.');
%         end
%         
%         tblMF = obj.trkPMD(:,{'mov' 'frm'});
%         tblLoad = tr.trkPMD(:,{'mov' 'frm'});
%         [tfOverlp,locMF] = ismember(tblLoad,tblMF);
%         
%         tsOverlp0 = obj.trkPTS(locMF(tfOverlp));
%         tsOverlpNew = tr.trkPTS(tfOverlp);
%         nOverlapOlder = nnz(tsOverlpNew<tsOverlp0);
%         if nOverlapOlder>0
%           warningNoTrace('CPRLabelTracker:trkPTS',...
%             'Loading tracking results that are older than current results for %d frames.',nOverlapOlder);
%         end
%         
%         % load existing/overlap results
%         iOverlp = locMF(tfOverlp);
%         obj.trkP(iOverlp,:,:) = tr.trkP(tfOverlp,:,:);
%         obj.trkPFull(iOverlp,:,:,:) = tr.trkPFull(tfOverlp,:,:,:); % TODO: if trkPFull is [] (stripped)
%         obj.trkPMD(iOverlp,:) = tr.trkPMD(tfOverlp,:);
%         obj.trkPTS(iOverlp,:) = tr.trkPTS(tfOverlp,:);
%         
%         % load new results
%         obj.trkP = cat(1,obj.trkP,tr.trkP(~tfOverlp,:,:));
%         obj.trkPFull = cat(1,obj.trkPFull,tr.trkPFull(~tfOverlp,:,:,:)); % TODO: if trkPFull is [] 
%         obj.trkPMD = cat(1,obj.trkPMD,tr.trkPMD(~tfOverlp,:));
%         obj.trkPTS = cat(1,obj.trkPTS,tr.trkPTS(~tfOverlp,:));
%       else
%         % code in the other branch would basically work, but we also want
%         % to set trkPiPt
%         props = obj.TRACKRES_SAVEPROPS;
%         for p=props(:)',p=p{1}; %#ok<FXSET>
%           obj.(p) = tr.(p);
%         end
%       end
%       
%       nfLoad = size(tr.trkP,1);
%       fprintf(1,'Loaded tracking results for %d frames.\n',nfLoad);
    end
    
    %#MV
    function track(obj,iMovs,frms,varargin)
      [tblP,stripTrkPFull,movChunkSize,p0DiagImg] = myparse(varargin,...
        'tblP',[],... % table with props {'mov' 'frm' 'p'} containing movs/frms to track
        'stripTrkPFull',true,... % if true, don't save .trkPFull
        'movChunkSize',5000, ... % track large movies in chunks of this size
        'p0DiagImg',[] ... % full filename; if supplied, create/save a diagnostic image of initial shapes for first tracked frame
        );
      
      prm = obj.sPrm;
      if isempty(prm)
        error('CPRLabelTracker:param','Please specify tracking parameters.');
      end
      if ~all([obj.trnResRC.hasTrained])
        error('CPRLabelTracker:track','No tracker has been trained.');
      end
      
      if isfield(prm.TestInit,'movChunkSize')
        movChunkSize = prm.TestInit.movChunkSize;
      end
                        
      if isempty(tblP)
        tblP = obj.getTblP(iMovs,frms);
        if isempty(tblP)
          msgbox('No frames specified for tracking.');
          return;
        end
      end
      
      nFrmTrk = size(tblP,1);
      iChunkStarts = 1:movChunkSize:nFrmTrk;
      nChunk = numel(iChunkStarts);
      for iChunk=1:nChunk
        
        idxP0 = (iChunk-1)*movChunkSize+1;
        idxP1 = min(idxP0+movChunkSize-1,nFrmTrk);
        tblPChunk = tblP(idxP0:idxP1,:);
        fprintf('Tracking frames %d through %d...\n',idxP0,idxP1);
        
        %%% Set up .data
        
        if nChunk>1
          % In this case we assume we are dealing with a 'big movie' and
          % don't preserve/cache data          
          obj.initData();
        end
        
        tblPChunk(:,'pTS') = [];
        obj.updateData(tblPChunk);
        d = obj.data;

        tblMFTrk = tblPChunk(:,{'mov' 'frm'});
        tblMFAll = d.MD(:,{'mov' 'frm'});
        [tf,loc] = ismember(tblMFTrk,tblMFAll);
        assert(all(tf));
        d.iTst = loc;
        
        fprintf(1,'Track data summary:\n');
        d.summarize('mov',d.iTst);
                
        [Is,nChan] = d.getCombinedIs(d.iTst);
        prm.Ftr.nChn = nChan;
        
        %% Test on test set
        NTst = d.NTst;
        RT = prm.TestInit.Nrep;

        nview = obj.sPrm.Model.nviews;
        nfids = prm.Model.nfids;
        assert(nview==numel(obj.trnResRC));
        assert(nview==size(Is,2));
        assert(prm.Model.d==2);
        Dfull = nfids*nview*prm.Model.d;
        pTstT = nan(NTst,RT,Dfull,prm.Reg.T+1);
        pTstTRed = nan(NTst,Dfull,prm.Reg.T+1);
        for iView=1:nview
          rc = obj.trnResRC(iView);
          IsVw = Is(:,iView);          
          bboxesVw = CPRData.getBboxes2D(IsVw);
          if nview==1
            assert(isequal(bboxesVw,d.bboxesTst));
          end
          
          [p_t,pIidx,p0,p0Info] = rc.propagateRandInit(IsVw,bboxesVw,prm.TestInit);
          if iChunk==1 && ~isempty(p0DiagImg)
            tf1 = pIidx==1;
            p0Info.p0_1 = p0(tf1,:);
            hFigP0DiagImg = RegressorCascade.createP0DiagImg(IsVw,p0Info);
            [ptmp,ftmp] = fileparts(p0DiagImg);
            p0DiagImgVw = fullfile(ptmp,sprintf('%s_view%d.fig',ftmp,iView));
            savefig(hFigP0DiagImg,p0DiagImgVw);
            delete(hFigP0DiagImg);
          end
          trkMdl = rc.prmModel;
          trkD = trkMdl.D;
          Tp1 = rc.nMajor+1;
          pTstTVw = reshape(p_t,[NTst RT trkD Tp1]);
          
          %% Select best preds for each time
          pTstTRedVw = nan(NTst,trkD,Tp1);
          prm.Prune.prune = 1;
          for t = 1:Tp1
            fprintf('Pruning t=%d\n',t);
            pTmp = permute(pTstTVw(:,:,:,t),[1 3 2]); % [NxDxR]
            pTstTRedVw(:,:,t) = rcprTestSelectOutput(pTmp,trkMdl,prm.Prune);
          end
          
          assert(trkD==Dfull/nview);
          assert(mod(trkD,2)==0);
          iFull = (1:nfids)+(iView-1)*nfids;
          iFull = [iFull,iFull+nfids*nview]; %#ok<AGROW>
          pTstT(:,:,iFull,:) = pTstTVw;
          pTstTRed(:,iFull,:) = pTstTRedVw;
        end
          
        % Augment .trkP* state with new tracking results
        % - new rows are just added
        % - existing rows are overwritten
        
        if ~isempty(obj.trkP)
          assert(~isempty(obj.trkPiPt),...
            'Tracked points specification (.trkPiPt) cannot be empty.');
          if ~isequal(obj.trkPiPt,obj.trnResIPt)
            error('CPRLabelTracker:track',...
              'Existing tracked points (.trkPiPt) differ from new tracked points. New tracking results cannot be saved.');
          end
        end
        
        trkPMDnew = d.MDTst(:,{'mov' 'frm'});
        trkPMDcur = obj.trkPMD;
        [tf,loc] = ismember(trkPMDnew,trkPMDcur);
        % existing rows
        idxCur = loc(tf);
        obj.trkP(idxCur,:,:) = pTstTRed(tf,:,:);
        if stripTrkPFull
          if ~isempty(obj.trkPFull)
            warning('CPRLabelTracker:track','Stripping 4D tracking results .trkPFull.');
            obj.trkPFull = [];
          end
        else
          obj.trkPFull(idxCur,:,:,:) = pTstT(tf,:,:,:);
        end        
        nowts = now;
        obj.trkPTS(idxCur) = nowts;
        % new rows
        obj.trkP = [obj.trkP; pTstTRed(~tf,:,:)];
        if ~stripTrkPFull
          obj.trkPFull = [obj.trkPFull; pTstT(~tf,:,:,:)];
        end
        nNew = nnz(~tf);
        obj.trkPTS = [obj.trkPTS; repmat(nowts,nNew,1)];
        obj.trkPMD = [obj.trkPMD; trkPMDnew(~tf,:)];        

        % See above check/error re .trkPiPt. Either there were originally no
        % tracking results so we are setting .trkPiPt for the first time; or
        % there were original tracking results and the old .trkPiPt matches
        % the new (in which case this line is a no-op).
        obj.trkPiPt = obj.trnResIPt;
      end
      
      if ~isempty(obj.lObj)
        obj.vizLoadXYPrdCurrMovie();
        obj.newLabelerFrame();
      else
        % headless mode
      end
    end
      
    %#MV
    function [trkfiles,tfHasRes] = getTrackingResults(obj,iMovs)
      % Get tracking results for movie(set) iMov.
      %
      % iMovs: [nMov] vector of movie(set) indices
      %
      % trkfiles: [nMovxnView] TrkFile objects
      % tfHasRes: [nMov] logical. If true, corresponding movie has tracking
      % nontrivial (nonempty) tracking results
      
      validateattributes(iMovs,{'numeric'},{'vector' 'positive' 'integer'});

      if isempty(obj.trkPTS)
        error('CPRLabelTracker:noRes','No current tracking results.');
      end
      
      nMov = numel(iMovs);
      trkpipt = obj.trkPiPt;
      trkinfobase = struct('paramFile',obj.paramFile);
      
      tfMultiView = obj.lObj.isMultiView;
      if tfMultiView
        nPhysPts = obj.lObj.nPhysPoints;
        nview = obj.lObj.nview;
        assert(isequal(trkpipt,1:nPhysPts*nview));
        ipt2vw = meshgrid(1:nview,1:nPhysPts);
        assert(isequal(obj.lObj.labeledposIPt2View,ipt2vw(:)));
      end
        
      for i = nMov:-1:1        
        [trkpos,trkposTS,trkposFull,tfHasRes(i)] = obj.getTrackResRaw(iMovs(i));        
        if tfMultiView
          assert(size(trkpos,1)==nPhysPts*nview);
          for ivw=nview:-1:1
            iptCurrVw = (1:nPhysPts) + (ivw-1)*nPhysPts;
            trkinfo = trkinfobase;
            trkinfo.view = ivw;
            trkfiles(i,ivw) = TrkFile(trkpos(iptCurrVw,:,:),...
              'pTrkFull',trkposFull(iptCurrVw,:,:,:),...
              'pTrkTS',trkposTS(iptCurrVw,:),...
              'pTrkiPt',1:nPhysPts,...
              'trkInfo',trkinfo);
          end
        else
          trkfiles(i,1) = TrkFile(trkpos,'pTrkFull',trkposFull,...
            'pTrkTS',trkposTS,'pTrkiPt',trkpipt,'trkInfo',trkinfobase);
        end
      end
    end
    
    function importTrackingResults(obj,iMovs,trkfiles)
      % Any existing tracking results in iMovs are OVERWRITTEN even if the
      % tracking results in trkfiles are all NaNs
      
      lObj = obj.lObj;
      validateattributes(iMovs,{'numeric'},...
        {'positive' 'integer' '<=' lObj.nmovies});
      nMovs = numel(iMovs);
      assert(isa(trkfiles,'TrkFile') && numel(trkfiles)==nMovs);

      prmFile0 = obj.paramFile;
      
      for i = 1:nMovs
        iMv = iMovs(i);
        tfile = trkfiles(i);
        movFileID = FSPath.standardPath(lObj.movieFilesAll{iMv});
        movFileFull = lObj.movieFilesAllFull{iMv};

        prmFile1 = tfile.trkInfo.paramFile;
        if ~isempty(prmFile0) && ~isempty(prmFile1) && ~strcmp(prmFile0,prmFile1)
          warningNoTrace('CPRLabelTracker:paramFile',...
            'Tracking results generated using parameter file ''%s'', which differs from current file ''%s''.',...
            prmFile1,prmFile0);
        end
        % Note, we do not force the prmFiles to agree. And maybe in some
        % weird cases, one or both are empty.
        
        nfrm = lObj.movieInfoAll{iMv}.nframes;
        if size(tfile.pTrk,3)~=nfrm
          error('CPRLabelTracker:importTrackingResults',...
            'Trkfile inconsistent with number of frames in movie %s.',movFileFull);
        end
                
        % find and clear all tracking results for this mov
        tfCurrMov = strcmp(obj.trkPMD.mov,movFileID);
        if any(tfCurrMov)
          warningNoTrace('CPRLabelTracker:importTrackingResults',...
            'Clearing %d frames of existing tracking results for movie %s.',...
            nnz(tfCurrMov),movFileID);
          obj.trkP(tfCurrMov,:,:) = [];
          if ~isempty(obj.trkPFull)
            assert(size(obj.trkPFull,1)==numel(tfCurrMov));
            obj.trkPFull(tfCurrMov,:,:,:) = [];
          end
          obj.trkPTS(tfCurrMov,:) = [];
          obj.trkPMD(tfCurrMov,:) = [];
        end
        
        % load tracking results for this mov
        
        % find frames that have at least one non-nan point
        
        d = 2;
        trkD = d*obj.nPtsTrk;
        tmptrkP = reshape(tfile.pTrk,trkD,nfrm)'; % [nfrm x trkD]
        tfNotNanFrm = any(~isnan(tmptrkP),2);
        nRowsToAdd = nnz(tfNotNanFrm);
        
        if nRowsToAdd>0
          if isempty(obj.trkPiPt)
            assert(isempty(obj.trkP));
            obj.trkPiPt = tfile.pTrkiPt;
          end
          if ~isequal(obj.trkPiPt,tfile.pTrkiPt)
            error('CPRLabelTracker:trkPiPt',...
              'Movie %s: ''trkPiPt'' differs in tracked results to be loaded.',...
              movFileFull);
          end        

          TRKMDVARNAMES = {'mov' 'frm'};
          assert(strcmp(obj.trkPMD.Properties.VariableNames,TRKMDVARNAMES));

          % OK: update .trkP, trkPFull, trkPMD, trkPTS
          obj.trkP = cat(1,obj.trkP,tmptrkP(tfNotNanFrm,:));
          if ~isempty(obj.trkPFull)
            obj.trkPFull = cat(1,obj.trkPFull,...
              nan(nRowsToAdd,size(obj.trkPFull,2),trkD,size(obj.trkPFull,4)));
          end
          mdMov = repmat({movFileID},nRowsToAdd,1);
          mdFrm = find(tfNotNanFrm);
          mdFrm = mdFrm(:);
          mdNew = table(mdMov,mdFrm,'VariableNames',TRKMDVARNAMES);
          obj.trkPMD = cat(1,obj.trkPMD,mdNew);
          tsNew = tfile.pTrkTS(:,tfNotNanFrm);
          tsNew = max(tsNew,1)';
          obj.trkPTS = cat(1,obj.trkPTS,tsNew);

          % tfile.pTrkTag is ignored
          tftmp = ~cellfun(@isempty,tfile.pTrkTag);
          if any(tftmp(:))
            warningNoTrace('CPRLabelTracker:importTrackingResults',...
              'Movie %s: Ignoring nontrivial .pTrkTag field in TrkFile.',movFileFull);
          end
          
          fprintf(1,'Movie %s: loaded %d frames of tracking results.\n',...
            movFileFull,nRowsToAdd);
        end
        
        assert(isequal(size(obj.trkP,1),size(obj.trkPMD,1),size(obj.trkPTS,1)));
      end
      fprintf(1,'Loaded tracking results for %d movies.\n',nMovs);
    end
    
    function clearTrackingResults(obj)
      obj.initData();
      obj.trackResInit();
    end
    
    function newLabelerFrame(obj)
      % Update .hXYPrdRed based on current Labeler frame and
      % .xyPrdCurrMovie

      npts = obj.nPts;
      % get xy and isinterp
      [xy,isinterp] = obj.getCurrentPrediction();
      
      if isinterp
        plotargs = obj.xyVizPlotArgsInterp;
      else
        plotargs = obj.xyVizPlotArgs;
      end      
      
      hXY = obj.hXYPrdRed;
      for iPt = 1:npts
        set(hXY(iPt),'XData',xy(iPt,1),'YData',xy(iPt,2),plotargs{:});
      end
    end
    
    function newLabelerMovie(obj)
      obj.vizLoadXYPrdCurrMovie();
      obj.newLabelerFrame();
    end
    
    function s = getSaveToken(obj)
      % See save philosophy below. ATM we return a "full" struct with
      % 2+3+4;
      
      s1 = obj.getTrainedTrackerSaveStruct();
      s2 = obj.getTrackResSaveStruct();
      assert(isequal(s1.paramFile,s2.paramFile));
      s2 = rmfield(s2,'paramFile');
      s = structmerge(s1,s2);
    end
    
    function loadSaveToken(obj,s)
      if isfield(s,'labelTrackerClass')
        s = rmfield(s,'labelTrackerClass'); % legacy
      end            
     
      % modernize params
      if isfield(s,'sPrm') && ~isempty(s.sPrm)
        s.sPrm = CPRLabelTracker.modernizeParams(s.sPrm);       
        
        % 20161017
        % changes to default params param.example.yaml:
        % - Model:nviews now necessary and defaults to 1
        % - TrainInit:augjitterfac, default val 16
        % - TestInit:augjitterfac, default val 16
        %
        % A bit of a bind here b/c some parameter state is dup-ed in
        % RegressorCascade (whoops); we do not want to
        % reinit RegressorCascade (.trnResRC) for legacy projs, because
        % legacy projs implicitly used all the above "new" parameters and 
        % so re-init is not necessary. See hack below.      
                
        % Hack, double-update legacy RegressorCascades (.trnResRC).
        rc = s.trnResRC;
        if ~isempty(rc) && isscalar(rc) 
          % 20161128: multiview projs (nonscalar rc) should not require
          % these updates.
          
          assert(isa(rc,'RegressorCascade')); % handle obj
          if isempty(rc.prmModel.nviews)
            assert(s.sPrm.Model.nviews==1); 
            rc.prmModel.nviews = 1;
          end
          if ~isfield(rc.prmTrainInit,'augjitterfac')
            assert(s.sPrm.TrainInit.augjitterfac==16);
            rc.prmTrainInit.augjitterfac = 16;
          end
        end
      else
        assert(isempty(s.trnResRC));
      end
      
      %%% 20161031 modernize tables: .trnDataTblP, .trkPMD
      
      % remove .movS field
      if ~isempty(s.trnDataTblP)
        s.trnDataTblP = MFTable.rmMovS(s.trnDataTblP);
      end
      if ~isempty(s.trkPMD)
        s.trkPMD = MFTable.rmMovS(s.trkPMD);
      end
      
      allProjMovIDs = FSPath.standardPath(obj.lObj.movieFilesAll);
      allProjMovsFull = obj.lObj.movieFilesAllFull;
      if obj.lObj.isMultiView
        nrow = size(allProjMovIDs,1);
        tmpIDs = cell(nrow,1);
        tmpFull = cell(nrow,1);
        for i=1:nrow
          tmpIDs{i} = MFTable.formMultiMovieID(allProjMovIDs(i,:));
          tmpFull{i} = MFTable.formMultiMovieID(allProjMovsFull(i,:));
        end
        allProjMovIDs = tmpIDs;
        allProjMovsFull = tmpFull;
      end
      % 20161128. Multiview tracking is being put in after the transition
      % to using movieIDs in all tables, so the replaceMovieFullWithMovieID
      % business in the following should be no-ops for multiview projects.
      if ~isempty(s.trnDataTblP)
        tblDesc = 'Training data';
        s.trnDataTblP = MFTable.replaceMovieFullWithMovieID(s.trnDataTblP,...
          allProjMovIDs,allProjMovsFull,tblDesc);
        CPRLabelTracker.warnMoviesMissingFromProj(s.trnDataTblP.mov,allProjMovIDs,tblDesc);
        MFTable.warnDupMovFrmKey(s.trnDataTblP,tblDesc);
      end
      if ~isempty(s.trkPMD)
        tblDesc = 'Tracking results';
        s.trkPMD = MFTable.replaceMovieFullWithMovieID(s.trkPMD,...
          allProjMovIDs,allProjMovsFull,tblDesc);
        CPRLabelTracker.warnMoviesMissingFromProj(s.trkPMD.mov,allProjMovIDs,tblDesc);
        MFTable.warnDupMovFrmKey(s.trkPMD,tblDesc);
      end
      
      % 20170405. trnDataDownSamp
      if ~isfield(s,'trnDataDownSamp')
        s.trnDataDownSamp = false;
      end

      % set parameter struct s.sPrm on obj
      assert(isfield(s,'paramFile'));
      if ~isequal(s.paramFile,obj.paramFile)
        warningNoTrace('CPRLabelTracker:paramFile',...
          'Setting parameter file to ''%s''.',s.paramFile);
      end
      obj.setParamContentsSmart(s.sPrm);
     
      % set everything else
      flds = fieldnames(s);
      flds = setdiff(flds,'sPrm');
      for f=flds(:)',f=f{1}; %#ok<FXSET>
        obj.(f) = s.(f);
      end
      
      obj.vizLoadXYPrdCurrMovie();
      obj.newLabelerFrame();
    end
    
    % KB20160724: made a function to get the prediction for the current
    % frame, copied code from newLabelerFrame, and replaced codeblock with
    % function call in newLabelerFrame
    function [xy,isinterp] = getCurrentPrediction(obj)
      
      frm = obj.lObj.currFrame;
      npts = obj.nPts;
      if isempty(obj.xyPrdCurrMovie)
        xy = nan(npts,2);
        isinterp = false;
      else
        % AL20160502: When changing movies, order of updates to 
        % lObj.currMovie and lObj.currFrame is unspecified. currMovie can
        % be updated first, resulting in an OOB currFrame; protect against
        % this.
        frm = min(frm,size(obj.xyPrdCurrMovie,3));
        
        xy = obj.xyPrdCurrMovie(:,:,frm); % [npt x d]
        isinterp = obj.xyPrdCurrMovieIsInterp(frm);
      end      
    end
    
  end
    
  %% Save, Load, Init etc
  % The serialization philosophy is as follows.
  %
  % At a high level there are four groups of state forming a linear
  % dependency chain (basically)
  % 0. sPrm: all state is dependent on parameters.
  % 1. (CPR)Data: .data, .dataTS.
  % 2. Training Data specification: .trnData*
  % 3. Training results (trained tracker): .trnRes*
  % 4: Tracking results: .trkP*
  %
  % - Often, the .data itself in 1) will be very large. So ATM we do not
  % save the .data itself.
  % - You might want to save just 2., but much more commonly you will want
  % to save 2+3. If you want to save 3, it really makes sense to save 2 as
  % well. So we support saving 2+3. This is saving/loading a "trained 
  % tracker".
  % - You might want to save 4. You might want to do this independent of
  % 2+3. So we support saving 4 orthogonally, although of course sometimes 
  % you will want to save everything.
  %
  methods
        
    function s = getTrainedTrackerSaveStruct(obj)
      s = struct();
      props = obj.TRAINEDTRACKER_SAVEPROPS;
      s.paramFile = obj.paramFile;
      for p=props(:)',p=p{1}; %#ok<FXSET>
        s.(p) = obj.(p);
      end
    end
    
    function s = getTrackResSaveStruct(obj)
      s = struct();
      s.paramFile = obj.paramFile;
      props = obj.TRACKRES_SAVEPROPS;
      for p=props(:)',p=p{1}; %#ok<FXSET>
        s.(p) = obj.(p);
      end
    end
    
%     function loadTrainedTrackerSaveStruct(obj,s)
%       if ~isempty(obj.paramFile) && ~isequal(s.paramFile,obj.paramFile)
%         warningNoTrace('CPRLabelTracker:paramFile',...
%           'Tracker trained using parameter file ''%s'', which differs from current file ''%s''.',...
%           s.paramFile,obj.paramFile);
%       end      
%       
%       obj.paramFile = s.paramFile;
%       props = obj.TRAINEDTRACKER_SAVEPROPS;
%       for p=props(:)',p=p{1}; %#ok<FXSET>
%         obj.(p) = s.(p);
%       end
%     end
    
%     function saveTrainedTracker(obj,fname)
%       s = obj.getTrainedTrackerSaveStruct(); %#ok<NASGU>
%       save(fname,'-mat','-struct','s');
%     end
    
%     function loadTrainedTracker(obj,fname)
%       s = load(fname,'-mat');
%       obj.loadTrainedTrackerSaveStruct(s);
%     end
        
%     function loadTrackResSaveStruct(obj,s)
%       if ~isempty(obj.paramFile) && ~isequal(s.paramFile,obj.paramFile)
%         warningNoTrace('CPRLabelTracker:paramFile',...
%           'Results tracked using parameter file ''%s'', which differs from current file ''%s''.',...
%           s.paramFile,obj.paramFile);
%       end
%       obj.paramFile = s.paramFile;
%       props = obj.TRACKRES_SAVEPROPS;
%       for p=props(:)',p=p{1}; %#ok<FXSET>
%         obj.(p) = s.(p);
%       end
%     end
    
%     function saveTrackRes(obj,fname)
%       s = obj.getTrackResSaveStruct(); %#ok<NASGU>
%       save(fname,'-mat','-struct','s');
%     end
    
    function trackResInit(obj)
      % init obj.TRACKRES_SAVEPROPS
      
      obj.trkP = [];
      obj.trkPFull = [];
      obj.trkPTS = zeros(0,1);
      obj.trkPMD = struct2table(struct('mov',cell(0,1),'frm',[]));
      obj.trkPiPt = [];
    end
    
  end
  
  %% Viz
  methods
    
    function vizInit(obj)
      obj.xyPrdCurrMovie = [];
      obj.xyPrdCurrMovieIsInterp = [];
      deleteValidHandles(obj.hXYPrdRed);
      obj.hXYPrdRed = [];
      
      % init .xyVizPlotArgs*
      trackPrefs = obj.lObj.projPrefs.Track;
      plotPrefs = trackPrefs.PredictPointsPlot;
      plotPrefs.HitTest = 'off';
      obj.xyVizPlotArgs = struct2paramscell(plotPrefs);
      if isfield(trackPrefs,'PredictInterpolatePointsPlot')
        obj.xyVizPlotArgsInterp = struct2paramscell(trackPrefs.PredictInterpolatePointsPlot);
      else
        obj.xyVizPlotArgsInterp = obj.xyVizPlotArgs;
      end      
      
      npts = obj.nPts;
      ptsClrs = obj.lObj.labelPointsPlotInfo.Colors;
      ax = obj.ax;
      arrayfun(@cla,ax);
      arrayfun(@(x)hold(x,'on'),ax);
      ipt2View = obj.lObj.labeledposIPt2View;
      hTmp = gobjects(npts,1);
      for iPt = 1:npts
        clr = ptsClrs(iPt,:);
        iVw = ipt2View(iPt);
        hTmp(iPt) = plot(ax(iVw),nan,nan,obj.xyVizPlotArgs{:},'Color',clr);
      end
      obj.hXYPrdRed = hTmp;
    end
    
    function vizLoadXYPrdCurrMovie(obj)
      % sets .xyPrdCurrMovie* for current Labeler movie from .trkP, .trkPMD
      %
      % TODO: collapse with getTrackRes(obj,iMov)

      lObj = obj.lObj;
      
      trkTS = obj.trkPTS;
      if isempty(trkTS) || lObj.currMovie==0
        obj.xyPrdCurrMovie = [];
        obj.xyPrdCurrMovieIsInterp = [];
        return;
      end

      movNameID = FSPath.standardPath(lObj.movieFilesAll(lObj.currMovie,:));
      movNameID = MFTable.formMultiMovieID(movNameID);
        
      nfrms = lObj.nframes;
      
      d = 2;
      nfids = obj.nPts;
      pTrk = obj.trkP(:,:,end);
      trkMD = obj.trkPMD;
      iPtTrk = obj.trkPiPt;
      nPtTrk = numel(iPtTrk);
      assert(isequal(size(pTrk),[size(trkMD,1) nPtTrk*d]));
      
      tfCurrMov = strcmp(trkMD.mov,movNameID); % these rows of trkMD are for the current Labeler movie
      nCurrMov = nnz(tfCurrMov);
      xyTrkCurrMov = reshape(pTrk(tfCurrMov,:)',nPtTrk,d,nCurrMov);
      
      frmCurrMov = trkMD.frm(tfCurrMov);
      xy = nan(nfids,d,nfrms);
      xy(iPtTrk,:,frmCurrMov) = xyTrkCurrMov;
      
      if obj.trkVizInterpolate
        [xy,isinterp3] = CPRLabelTracker.interpolateXY(xy);
        isinterp = CPRLabelTracker.collapseIsInterp(isinterp3(iPtTrk,:,:));
      else
        isinterp = false(nfrms,1);
      end
      
      obj.xyPrdCurrMovie = xy;
      obj.xyPrdCurrMovieIsInterp = isinterp;
    end

    function vizHide(obj)
      [obj.hXYPrdRed.Visible] = deal('off');
      obj.hideViz = true;
    end
    
    function vizShow(obj)
      [obj.hXYPrdRed.Visible] = deal('on'); 
      obj.hideViz = false;
    end
    
    function vizInterpolateXYPrdCurrMovie(obj)
      [obj.xyPrdCurrMovie,isinterp3] = CPRLabelTracker.interpolateXY(obj.xyPrdCurrMovie);
      obj.xyPrdCurrMovieIsInterp = CPRLabelTracker.collapseIsInterp(isinterp3);
    end
    
  end

  %%
  methods (Static)
    
    function sPrm0 = readDefaultParams
      sPrm0 = ReadYaml(CPRLabelTracker.DEFAULT_PARAMETER_FILE);
    end
    
    function sPrm = modernizeParams(sPrm)
      s0 = CPRLabelTracker.readDefaultParams();
      [sPrm,s0used] = structoverlay(s0,sPrm);
      if ~isempty(s0used)
        fprintf('Using default parameters for: %s.\n',...
          String.cellstr2CommaSepList(s0used));
      end
      if isempty(sPrm.Model.nviews)
        % Model.nviews now required. structoverlay would not overlay new
        % default value on top of existing/legacy empty [] value.
        sPrm.Model.nviews = 1;
      end      
    end
    
    function warnMoviesMissingFromProj(movs,movsProj,movTypeStr)
      tfMissing = ~ismember(movs,movsProj);
      movMiss = movs(tfMissing);
      movMiss = unique(movMiss);
      cellfun(@(x)warningNoTrace('CPRLabelTracker:mov',...
        '%s movie not in project: ''%s''',movTypeStr,x),movMiss);
    end
    
    function [xy,isinterp] = interpolateXY(xy)
      % xy (in): [npts d nfrm]
      %
      % xy (out): [npts d nfrm]. Like input, but with nans replaced with
      % values by interpolating along 3rd dim 
      % isinterp: [npts d nfrm] logical.
      
      isinterp = false(size(xy));
      for iPt = 1:size(xy,1)
        for d = 1:size(xy,2)
          z = squeeze(xy(iPt,d,:));
          tf = ~isnan(z);
          if any(tf) % must have at least one nonnan value to interpolate
            iGood = find(tf);
            iNan = find(~tf);
            z(iNan) = interp1(iGood,z(iGood),iNan);
            xy(iPt,d,:) = z;
            isinterp(iPt,d,iNan) = true;
          end
        end
      end
    end
    
    function isinterp1 = collapseIsInterp(isinterp3)
      % isinterp3: [nptsxdxnfrm] logical, see interpolateXY().
      %
      % isinterp1: [nfrm] logical. isinterp1(i) is true if all elements of
      % isinterp3(:,:,i) are true.
      
      [npts,d,nfrm] = size(isinterp3);
      isinterp2 = reshape(isinterp3,[npts*d,nfrm]);
      
      tfall = all(isinterp2,1);
      tfany = any(isinterp2,1);
      tfmixed = tfany & ~tfall;
      nfrmmixed = nnz(tfmixed);
      if nfrmmixed>0
        warning('CPRLabelTracker:isinterp','%d/%d frames have some interpolated and some non-interpolated tracking results. Treating these frames as non-interpolated.',...
          nfrmmixed,nfrm);
      end
      
      isinterp1 = tfall(:);
    end
    
    function tdPPJan(td,varargin)
      td.computeIpp([],[],[],'iTrl',1:td.N,'jan',true,varargin{:});
    end
    
    function tdPPRF(td,varargin)
      td.computeIpp([],[],[],'iTrl',1:td.N,'romain',true,varargin{:});
    end
    
    function tdPPRFfull(td,varargin)
      bppFile = '/groups/branson/home/leea30/rf/2dbot/blurPreProc_21chan.mat';
      bpp = load(bppFile);
      bpp = bpp.bpp(1);
      td.computeIpp([],[],[],'iTrl',1:td.N,'romain',bpp,varargin{:});
    end
    
    function tdPP2dL(td,varargin)
      bppFile = '/groups/branson/home/leea30/rf/rfBlurPreProc.mat';
      bpp = load(bppFile);
      bpp = bpp.bpp(1);
      td.computeIpp([],[],[],'iTrl',1:td.N,'romain',bpp,varargin{:});
    end
    
    function tdPP2dR(td,varargin)
      bppFile = '/groups/branson/home/leea30/rf/rfBlurPreProc.mat';
      bpp = load(bppFile);
      bpp = bpp.bpp(2);
      td.computeIpp([],[],[],'iTrl',1:td.N,'romain',bpp,varargin{:});
    end
    
  end
  
end
% AL20160912: this is giving the CPR.Root error, maybe it's too complicated
% for current MATLAB class init
% AL20161017: CPR.Root error persists even if not using this fcn; meanwhile
% build is broken without it
function dpf = lclInitDefaultParameterFile()

if isdeployed
  dpf = fullfile(ctfroot,'param.example.yaml');
else
  cprroot = fileparts(fileparts(mfilename('fullpath')));
  dpf = fullfile(cprroot,'param.example.yaml');
end
end