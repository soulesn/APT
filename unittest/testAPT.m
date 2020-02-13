classdef testAPT < handle
  
  % To test:
  % tt = testAPT(); tt.test_full();
  
  properties
    lObj = [];
    info = [];
    old_lbl = [];
  end
  
  methods (Static)
    
    function setup()
      addpath('..');
      APT.setpath;
    end
    
    function create_bundle(varargin)
      % creates a targz to upload to Drobox
      name = myparse(varargin,'name','alice');
      testAPT.setup()
      info = testAPT.get_info(name);
      ref_lbl = info.ref_lbl;
      exp_dir_base = info.exp_dir_base;
      
      proj_name = [name '_test'];
      old_lbl = loadLbl(ref_lbl);
      old_lbl.movieFilesAll = FSPath.macroReplace(old_lbl.movieFilesAll,struct('dataroot',exp_dir_base));
      old_lbl.movieFilesAllGT = FSPath.macroReplace(old_lbl.movieFilesAllGT,struct('dataroot',exp_dir_base));

      tdir = fullfile(tempname,'alice_test');
      mkdir(tdir);
      all_m = old_lbl.movieFilesAll;
      for ndx = 1:numel(all_m)
        [~,exp_name] = fileparts(fileparts(all_m{ndx}));
        outdir = fullfile(tdir,exp_name);
        if ~exist(outdir,'dir'),
          mkdir(outdir);
        end
        copyfile(all_m{ndx},outdir);
        if info.has_trx
          trx_file_name = old_lbl.trxFilesAll{ndx};
          trx_file_name = strrep(trx_file_name,'$movdir',fullfile(exp_dir_base,exp_name));
          copyfile(trx_file_name,outdir);
        end
      end
      copyfile(info.ref_lbl,tdir);
      tar(fullfile(tempdir,[proj_name '_data.tar.gz']),tdir,tdir);
      rmdir(tdir);
    end
    
    function cdir = get_cache_dir()
      if ispc
        userDir = winqueryreg('HKEY_CURRENT_USER',...
          ['Software\Microsoft\Windows\CurrentVersion\' ...
          'Explorer\Shell Folders'],'Personal');
      else
        userDir = char(java.lang.System.getProperty('user.home'));
      end
      cdir = fullfile(userDir,'.apt');
    end
    
  end
  
  
  methods
    
    function get_info(self,name)
      info = struct;
      if strcmp(name,'alice')      
%         info.ref_lbl = '/work/mayank/work/FlySpaceTime/multitarget_bubble_expandedbehavior_20180425_fixederrors_fixed.lbl';
        info.ref_lbl = '/groups/branson/home/robiea/Projects_data/Labeler_APT/Austin_labelerprojects_expandedbehaviors/multitarget_bubble_expandedbehavior_20180425_allGT_MK_MDN04182019.lbl';
        info.exp_dir_base = '/groups/branson/home/robiea/Projects_data/Labeler_APT';
        info.nviews = 1;
        info.npts = 17;
        info.has_trx = true;
        info.proj_name = 'alice_test';
        info.sz = 90;
        info.bundle_link = 'https://www.dropbox.com/s/u5p27rdi7kczv78/alice_test_data.tar.gz?dl=1';
      else
        error('Unrecognized test name');
      end
      self.info = info;
    end
        
    function [data_dir, lbl_file] = get_file_paths(self)
      info = self.info;
      cacheDir = testAPT.get_cache_dir();
      data_dir = fullfile(cacheDir,info.proj_name);
      [~,lbl_name,ext] = fileparts(info.ref_lbl);
      lbl_file = fullfile(data_dir,[lbl_name ext]);
    end
    
    function ok = exist_files(self)
      old_lbl = self.old_lbl;
      info = self.info;
      ok = true;
      for ndx = 1:numel(old_lbl.movieFilesAll),
        if ~exist(old_lbl.movieFilesAll{ndx},'file')
            ok = false;
            return;          
        end
        if info.has_trx && ~exist(old_lbl.trxFilesAll{ndx},'file')
            ok = false;
            return;          
        end        
      end
      
    end
    
    function load_lbl(self)
      info = self.info;
      [data_dir, lbl_file] = self.get_file_paths();
      if ~exist(lbl_file,'file')
        testAPT.setup_data(info);
      end
      old_lbl = loadLbl(lbl_file);
      old_lbl.movieFilesAll = FSPath.macroReplace(old_lbl.movieFilesAll,old_lbl.projMacros);
      old_lbl.movieFilesAllGT = FSPath.macroReplace(old_lbl.movieFilesAllGT,old_lbl.projMacros);
      all_m = old_lbl.movieFilesAll;
      for ndx = 1:numel(old_lbl.movieFilesAll)
        [tt,mov_name,mext] = fileparts(all_m{ndx});
        [~,exp_name] = fileparts(tt);
        old_lbl.movieFilesAll{ndx} = fullfile(data_dir,exp_name,[mov_name mext]);
        if info.has_trx
          trx_file_name = old_lbl.trxFilesAll{ndx};
          trx_file_name = strrep(trx_file_name,'$movdir',fullfile(data_dir,exp_name));
          old_lbl.trxFilesAll{ndx} = trx_file_name;
        end
      end
      all_m = old_lbl.movieFilesAllGT;
      for ndx = 1:numel(all_m)
        [tt,mov_name,mext] = fileparts(all_m{ndx});
        [~,exp_name] = fileparts(tt);
        old_lbl.movieFilesAllGT{ndx} = fullfile(data_dir,exp_name,[mov_name mext]);
        if info.has_trx
          trx_file_name = old_lbl.trxFilesAllGT{ndx};
          trx_file_name = strrep(trx_file_name,'$movdir',fullfile(data_dir,exp_name));
          old_lbl.trxFilesAllGT{ndx} = trx_file_name;
        end
      end
      self.old_lbl = old_lbl;
    end
    
    function setup_data(self)
      info = self.info;
      cacheDir = get_cache_dir(info);
      out_file = fullfile(tempdir,[info.proj_name '_data.tar.gz']); 
      if exist(out_file,'file')
        try
          untar(out_file,cacheDir);
        catch ME
          websave(out_file,info.bundle_link);
          untar(out_file,cacheDir);
        end
      else
          websave(out_file,info.bundle_link);
          untar(out_file,cacheDir);          
      end
    end
    
    function test_full(self,varargin)
      [name] = myparse(varargin,'name','alice');
      testAPT.setup();
      self.get_info(name);
      self.load_lbl();
      old_lbl = self.old_lbl;
      if ~self.exist_files()
        self.setup_data();
      end
      
      lObj = self.create_project();
      self.lObj = lObj;
      self.add_movies();
%      testAPT.add_labels(old_lbl,lObj,info);
      self.add_labels_quick();      
      self.setup_alg('mdn')
      self.set_params(self.info.has_trx,1000,self.info.sz);
      self.set_backend('docker');
      self.test_train();
      while self.lObj.tracker.bgTrnIsRunning(),        
        pause(10);
      end
      self.test_track();
    end
    
    function lObj = create_project(self)
     % Create the new project
      info = self.info;
      lObj = Labeler;
      cfg = Labeler.cfgGetLastProjectConfigNoView;
      cfg.NumViews = info.nviews;
      cfg.NumLabelPoints = info.npts;
      cfg.Trx.HasTrx = info.has_trx;
      cfg.ViewNames = {};
      cfg.LabelPointNames = {};
      cfg.Track.Enable = true;
      cfg.ProjectName = info.proj_name;
      FIELDS2DOUBLIFY = {'Gamma' 'FigurePos' 'AxisLim' 'InvertMovie' 'AxFontSize' 'ShowAxTicks' 'ShowGrid'};
      for i=1:numel(cfg.View)  
        cfg.View(i) = ProjectSetup('structLeavesStr2Double',cfg.View(i),FIELDS2DOUBLIFY);
      end

      lObj.initFromConfig(cfg);
      lObj.projNew(cfg.ProjectName);
    end
    
    function add_movies(self)
      % Add movies
      lObj = self.lObj;
      old_lbl = self.old_lbl;
      info = self.info;
      nmov = size(old_lbl.movieFilesAll,1);
      for ndx = 1:nmov
          if info.has_trx
              lObj.movieAdd(old_lbl.movieFilesAll{ndx,1},old_lbl.trxFilesAll{ndx,1});
          else
              lobj.movieSetAdd(old_lbl.movieFilesAll(ndx,:));
          end
      end
      lObj.movieSet(1,'isFirstMovie',true);
    end
    
    function add_labels_quick(self)
      old_lbl = self.old_lbl;
      lObj = self.lObj;
      info = self.info;

      % create the table      
      for ndx = 1:numel(old_lbl.labeledpos)
        cur_l = SparseLabelArray.full(old_lbl.labeledpos{ndx});
        cur_o = SparseLabelArray.full(old_lbl.labeledpostag{ndx});
        ss = size(cur_l);
        tgt = zeros(0,1); frm = zeros(0,1);
        p = zeros(0,ss(1)*ss(2));
        occ = false(0,ss(1));
        for tndx = 1:size(cur_l,4)
          cc = reshape(cur_l(:,:,:,tndx),[ss(1)*ss(2) ss(3)]);
          cur_idx = find(any(~isnan(cc),1));
          for lndx = 1:numel(cur_idx)
            tgt(end+1,:) = tndx;
            p(end+1,:) = cc(:,cur_idx(lndx))';
            occ(end+1,:) = cur_o(:,cur_idx(lndx))';
            frm(end+1,:) = cur_idx(lndx);
          end
        end
        tbl = table(frm,tgt,p,occ,'VariableNames',{'frm','iTgt','p','tfocc'});
        lObj.labelPosBulkImportTblMov(tbl,ndx);
      end      
      
    end
    
    function add_labels(self)
      % add the labels
      old_lbl = self.old_lbl;
      lObj = self.lObj;
      info = self.info;

      lc = lObj.lblCore;

      nmov = size(old_lbl.movieFilesAll,1);
      for ndx = 1:nmov
          lObj.movieSet(ndx);
          old_labels = SparseLabelArray.full(old_lbl.labeledpos{ndx});
          ntgts = size(old_labels,4);
          for itgt = 1:ntgts

              frms = find(squeeze(any(any(~isnan(old_labels(:,:,:,itgt)),1),2)));
              if isempty(frms), continue; end        
              for fr = 1:numel(frms)
                  cfr = frms(fr);
                  lObj.setFrameAndTarget(cfr,itgt);
                  for pt = 1:info.npts
                      lc.hPts(pt).XData = old_labels(pt,1,cfr,itgt);
                      lc.hPts(pt).YData = old_labels(pt,2,cfr,itgt);
                  end
                  lc.acceptLabels()
              end        
          end    
      end
    end
    
    
    function lObj = setup_lbl(self,ref_lbl)
      % Start from label file

      lObj = Labeler;
      lObj.projLoad(ref_lbl);
    end


    function setup_alg(self,alg)
      % Set the algorithm.
      old_lbl = self.old_lbl;
      lObj = self.lObj;
      info = self.info;

      nalgs = numel(lObj.trackersAll);
      tndx = 0;
      for ix = 1:nalgs
          if strcmp(lObj.trackersAll{ix}.algorithmName,alg)
              tndx = ix;
          end
      end

      assert(tndx > 0)
      lObj.trackSetCurrentTracker(tndx);
    end
    
    function set_params(self, has_trx, dl_steps,sz)
      lObj = self.lObj;
      % set some params
      tPrm = APTParameters.defaultParamsTree;
      sPrm = tPrm.structize;      
      sPrm.ROOT.DeepTrack.GradientDescent.dl_steps = 1000;
      sPrm.ROOT.ImageProcessing.MultiTarget.TargetCrop.Radius = sz;
      if has_trx,        
        sPrm.ROOT.ImageProcessing.MultiTarget.TargetCrop.AlignUsingTrxTheta = has_trx;
      end
      lObj.trackSetParams(sPrm);

    end
    
    function set_backend(self,backend)
      lObj = self.lObj;

      % Set the Backend
      if strcmp(backend,'docker')
        beType = DLBackEnd.Docker;
      end
      be = DLBackEndClass(beType,lObj.trackGetDLBackend);
      lObj.trackSetDLBackend(be);

    end
    
    % train
    function test_train(self)
      lObj = self.lObj;
      handles = lObj.gdata;
      oc1 = onCleanup(@()ClearStatus(handles));
      wbObj = WaitBarWithCancel('Training');
      oc2 = onCleanup(@()delete(wbObj));
      centerOnParentFigure(wbObj.hWB,handles.figure);
      handles.labelerObj.trackRetrain('retrainArgs',{'wbObj',wbObj});
      if wbObj.isCancel
        msg = wbObj.cancelMessage('Training canceled');
        msgbox(msg,'Train');
      end
    end
    
    function test_track(self)
      kk = LabelerGUI('get_local_fn','pbTrack_Callback');
      kk(self.lObj.gdata.pbTrack,[],self.lObj.gdata);
    end
    
  end
end