% Train function
%       + phisTr: training labels.
%       + bboxesTr: bounding boxes.
%       + IsTr: training images
%
%       AL 20160314: semi-obsolete stuff
% 
%       + cpr_type: 1 for Cao et al 2013, 2 for Burgos-Artizzu et al 2013
%       (without occlusion) and 3 for Burgos-Artizzu et al 2013
%       (occlusion).
%       + model_type: 'larva' (Marta's larvae with two muscles and two
%       landmarks for muscle), 'mouse_paw' (Adam's mice with one landmarks in one
%       view), 'mouse_paw2' (Adam's mice with two landmarks, one in each
%       view), 'mouse_paw3D' (Adam's mice, one landmarks in the 3D
%       reconstruction), fly_RF2 (Romain's flies, six landmarks)
%       + feature type: for 1-4 see FULL_demoRCPR.m, 5 for points in an
%       elipse with focus in any pair of landmarks, and 6 for points in a
%       circunference around each landmark.
%       + radius: dimensions of the area where features are computed, for
%       feature_type=5 (recomended 1.5) is the semi-major axis, for
%       feature_type=6 is the radius of the circumference (recomended 25). 
%       + Prm3D: parameters for 3D rexontruction (empty if 2D).
%       + pStar: initial position of the the labels (optional)
%       + regModel: regression model
%       + regPrm: regression parameters (using the paramters recomended in
%       Burgos-Artizzu et al 2013).
%       + prunePrm: prune parameters using the paramters recomended in
%       Burgos-Artizzu et al 2013).

function [regModel,regPrm,prunePrm,phisPr,err] = ...
  train(phisTr,bboxesTr,IsTr,varargin)

if isdeployed
  rng('shuffle');
end

[modelPrms,...
  regPrm,...
  ftrPrm,...
  initPrm,...
  prunePrm,...
  pStar,...
  nthreads,...
  docomperr,...
  expidx,ncrossvalsets,cvidx,cvi,fractrain,nsets_train,... % CV stuff
  savefile] = ...
  myparse(varargin,...
  'modelPrms',[],...
  'regPrm',[],...
  'ftrPrm',[],...
  'initPrm',[],... 
  'prunePrm',[],...
  'pStar',[],...
  'nthreads',[],...
  'docomperr',true,...
  'expidx',[],'ncrossvalsets',0,'cvidx',[],'cvi',[],'fractrain',1,'nsets_train',[],...
  'savefile','');

if isdeployed && ~isempty(nthreads)
  if ischar(nthreads)
    nthreads = str2double(nthreads);
  end
  maxNumCompThreads(nthreads);
end

if isdeployed && ischar(fractrain)
  fractrain = str2double(fractrain);
end

if isdeployed && ischar(nsets_train)
  nsets_train = str2double(nsets_train);
end

% by default, minimum image size / 2
if isempty(ftrPrm.radius)
  sz = min(cellfun(@(x) min(size(x,1),size(x,2)),IsTr));
  ftrPrm.radius = sz / 4;
end

% for hold-out set splitting
if isempty(expidx)
  expidx = 1:size(phisTr,1);
end

model = shapeGt('createModel',modelPrms.name,modelPrms.d,modelPrms.nfids,...
  modelPrms.nviews);
if model.d==3 && isempty(modelPrms.Prm3D)
  error('Calibration data must be input for 3d models');
end

docomperr = nargout >= 5 || (~isempty(savefile) && docomperr);

% TRAIN
if ncrossvalsets > 1
  assert(false,'AL');

  if isempty(cvidx) && ~isempty(cvi),
    error('Cannot set cvi and not cvidx');
  end
  
  if isempty(cvidx),  
    cvidx = CVSet(expidx,ncrossvalsets);
  end

  if isempty(cvi),

    regModel = cell(1,ncrossvalsets);
    phisPr = nan(size(phisTr));
    
    for cvi = 1:ncrossvalsets,
      
      idxtrain = cvidx ~= cvi;
      
      if fractrain < 1,
        
        idxtrain = find(idxtrain);
        ntraincurr = numel(idxtrain);
        ntraincurr1 = max(1,round(ntraincurr*fractrain));
        idxtrain1 = randsample(ntraincurr,ntraincurr1);
        idxtrain = idxtrain(sort(idxtrain1));
        fprintf('CV set %d, training on %d / %d training examples\n',cvi,ntraincurr1,ntraincurr);
        
      elseif ~isempty(nsets_train) && nsets_train < ncrossvalsets-1,
        
        ntraincurr = nnz(idxtrain);
        cvallowed = [1:cvi-1,cvi+1:ncrossvalsets];
        cvtrain = cvallowed(randsample(ncrossvalsets-1,nsets_train));
        idxtrain = ismember(cvidx,cvtrain);
        fprintf('CV set %d, training on %d / %d training examples (%d / %d cv sets)\n',cvi,nnz(idxtrain),ntraincurr,...
          nsets_train,ncrossvalsets-1);
        
      end
      
      idxtest = cvidx == cvi;
      
      fprintf('Training for cross-validation set %d / %d\n',cvi,ncrossvalsets);
      
      regModel{cvi} = train1(phisTr(idxtrain,:),bboxesTr(idxtrain,:),IsTr(idxtrain),...
        pStar,model,regPrm,ftrPrm,initPrm);
      
      if dcomperr,
        phisPr(idxtest,:) = test_rcpr([],bboxesTr(idxtest,:),IsTr(idxtest),regModel{cvi},regPrm,prunePrm);
        
        [errPerEx] = shapeGt('dist',model,phisPr(idxtest,:),phisTr(idxtest,:));
        errcurr = mean(errPerEx);
        
        %errcurr = mean( sqrt(sum( (phisPr(idxtest,:)-phisTr(idxtest,:)).^2, 2)) );
        fprintf('Error for validation set %d = %f\n',cvi,errcurr);
      end
    
    end
    
    if docomperr,
      [errPerEx] = shapeGt('dist',model,phisPr,phisTr);
      err = mean(errPerEx);
      %err = mean( sqrt(sum( (phisPr-phisTr).^2, 2)) );
    else
      phisPr = [];
      err = [];
    end
        
  else
    
    if ischar(cvi),
      cvi = str2double(cvi);
    end
    
    idxtrain = cvidx ~= cvi;
    
    if fractrain < 1,
      
      idxtrain = find(idxtrain);
      ntraincurr = numel(idxtrain);
      ntraincurr1 = max(1,round(ntraincurr*fractrain));
      idxtrain1 = randsample(ntraincurr,ntraincurr1);
      idxtrain = idxtrain(sort(idxtrain1));
      fprintf('CV set %d, training on %d / %d training examples\n',cvi,ntraincurr1,ntraincurr);
      
    elseif ~isempty(nsets_train) && nsets_train < ncrossvalsets-1,
      
      ntraincurr = nnz(idxtrain);
      cvallowed = [1:cvi-1,cvi+1:ncrossvalsets];
      cvtrain = cvallowed(randsample(ncrossvalsets-1,nsets_train));
      idxtrain = ismember(cvidx,cvtrain);
      fprintf('CV set %d, training on %d / %d training examples (%d / %d cv sets)\n',cvi,nnz(idxtrain),ntraincurr,...
        nsets_train,ncrossvalsets-1);
      
    end
    
    idxtest = cvidx == cvi;
    
    fprintf('Training for cross-validation set %d / %d\n',cvi,ncrossvalsets);
    
    regModel = train1(phisTr(idxtrain,:),bboxesTr(idxtrain,:),IsTr(idxtrain),...
      pStar,model,regPrm,ftrPrm,initPrm);

    if ~isempty(savefile),      
      %save(savefile,'regModel','regPrm','prunePrm','paramfile1','paramfile2','cvidx');
      save(savefile,'regModel','regPrm','prunePrm','cvidx');
    end

    if docomperr,
      phisPr = test_rcpr([],bboxesTr(idxtest,:),IsTr(idxtest),regModel,regPrm,prunePrm);
      
      [errPerEx] = shapeGt('dist',model,phisPr,phisTr(idxtest,:));
      err = mean(errPerEx);
      fprintf('Error for validation set %d = %f\n',cvi,err);
    else
      phisPr = [];
      err = [];
    end
    
  end
else  
  cvidx = true(size(expidx)); %#ok<NASGU>  
  regModel = train1(phisTr,bboxesTr,IsTr,pStar,model,regPrm,ftrPrm,initPrm);
  if docomperr
    phisPr = test_rcpr([],bboxesTr,IsTr,regModel,regPrm,prunePrm);
    err = mean( sqrt(sum( (phisPr-phisTr).^2, 2)) );
  else
    phisPr = [];
    err = [];
  end    
end

if ~isempty(savefile)  
  save(savefile,'regModel','regPrm','ftrPrm','initPrm','prunePrm','phisPr','err','cvidx');
end
  
if isdeployed
  delete(findall(0,'type','figure'));
end

function regModel = train1(phisTr,bboxesTr,IsTr,pStar,model,regPrm,ftrPrm,initPrm)
  
% augment data
[pCur,pGt,pGtN,pStar,imgIds,N,N1] = shapeGt('initTr',...
  IsTr,phisTr,model,pStar,bboxesTr,initPrm.Naug,initPrm.augpad,initPrm.augrotate);
initData = struct('pCur',pCur,'pGt',pGt,'pGtN',pGtN,'pStar',pStar,...
  'imgIds',imgIds,'N',N,'N1',N1);

trainPrm = struct('model',model,'pStar',[],'posInit',bboxesTr,...
  'T',regPrm.T,'L',initPrm.Naug,'regPrm',regPrm,'ftrPrm',ftrPrm,...
  'pad',initPrm.augpad,'verbose',1,'initData',initData,...
  'dorotate',initPrm.augrotate);
if model.d==3
  trainPrm.Prm3D = modelPrms.Prm3D;
end
  
[regModel,~] = rcprTrain(IsTr,phisTr,trainPrm);
