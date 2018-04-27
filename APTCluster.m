function APTCluster(varargin)
% Compiled APT operations
%
% % Do a full retrain of a project's tracker
% APTCluster(lblFile,'retrain')
%
% % Track a single movie
% APTCluster(lblFile,'track',moviefullpath)
%
% APTCluster(lblFile,'track',moviefullpath,trxfullpath)
%
% % Options passed to Labeler.trackAndExport, 'trackArgs'
% APTCluster(lblFile,'track',moviefullpath,trxfullpath,varargin)
% 
% % Track a set of movies
% APTCluster(lblFile,'trackbatch',moviesetfile,varargin)

lblFile = varargin{1};
action = varargin{2};
  
if exist(lblFile,'file')==0
  error('APTCluster:file','Cannot find project file: ''%s''.',lblFile);
end

lObj = Labeler();
set(lObj.hFig,'Visible','off');
fprintf('APTCluster: ''%s'' on project ''%s''.\n',action,lblFile);

switch action
  case 'retrain'
    lObj.projLoad(lblFile);
    lObj.trackRetrain();
    [p,f,e] = fileparts(lblFile);
    outfile = fullfile(p,[f '_retrain' datestr(now,'yyyymmddTHHMMSS') e]);
    fprintf('APTCluster: saving retrained project: %s\n',outfile);
    lObj.projSaveRaw(outfile);
  case 'track'
    lObj.projLoad(lblFile,'nomovie',true);
    mov = varargin{3};
    if nargin>3
      trxfile = varargin{4};
      trackArgs = varargin(5:end);
    else
      trxfile = '';
      trackArgs = {};
    end      
    lclTrackAndExportSingleMov(lObj,mov,trxfile,trackArgs);    
  case 'trackbatch'
    lObj.projLoad(lblFile,'nomovie',true);
    movfile = varargin{3};
    if exist(movfile,'file')==0
      error('APTCluster:file','Cannot find batch movie file ''%s''.',movfile);
    end
    movs = importdata(movfile);
    if ~iscellstr(movs) 
      error('APTCluster:movfile','Error reading batch movie file ''%s''.',movfile);
    end
    nmov = numel(movs);
    for iMov = 1:nmov
      lclTrackAndExportSingleMov(lObj,movs{iMov},'',{});
    end
  otherwise
    error('APTCluster:action','Unrecognized action ''%s''.',action);
end

delete(lObj);
close all force;


function lclTrackAndExportSingleMov(lObj,mov,trx,trackArgs)
% Trx: optional, specify '' for no-trx

if lObj.gtIsGTMode
  error('APTCluster:gt','Unsupported for GT mode.');
end
if lObj.isMultiView
  error('APTCluster:multiview','Unsupported for multiview projects.');
end
if exist(mov,'file')==0
  error('APTCluster:file','Cannot find movie file ''%s''.',mov);
end
tfTrxIn = ~isempty(trx);
if tfTrxIn && exist(trx,'file')==0
  error('APTCluster:file','Cannot find trx file ''%s''.',trx);
end

mov = FSPath.fullyLocalizeStandardizeChar(mov,struct());
[tfMovInProj,iMov] = ismember(mov,lObj.movieFilesAllFull);
if tfTrxIn
  trx = FSPath.fullyLocalizeStandardizeChar(trx,struct());
  [tfTrxInProj,iTrx] = ismember(trx,lObj.trxFilesAllFull);
end

if tfMovInProj
  if tfTrxIn
    if tfTrxInProj && iTrx==iMov
      % (mov,trx) is already in proj
      
      % no action; iMov is set        
    else
      warningNoTrace('Movie ''%s'' exists in project, but not with trxfile ''%s''.',...
        mov,trx);
      % Attempt to add new (mov,trx) pair
      lObj.movieAdd(mov,trx);
      iMov = numel(lObj.movieFilesAllFull);        
    end
  else
    % no action; iMov is set
  end
else
  % mov is not in proj
  lObj.movieAdd(mov,trx);
  iMov = numel(lObj.movieFilesAllFull);
end
lObj.movieSet(iMov);
assert(strcmp(lObj.movieFilesAllFull{lObj.currMovie},mov));

% filter/massage trackArgs
trackArgs = trackArgs(:);

i = find(strcmpi(trackArgs,'rawtrkname'));
assert(isempty(i) || isscalar(i));
trkFilenameArgs = trackArgs(i:i+1);
trackArgs(i:i+1,:) = [];

i = find(strcmpi(trackArgs,'startFrame'));
assert(isempty(i) || isscalar(i));
startArgs = trackArgs(i:i+1);
trackArgs(i:i+1,:) = [];
if numel(startArgs)==2 && ischar(startArgs{2})
  startArgs{2} = str2double(startArgs{2});
end  
i = find(strcmpi(trackArgs,'endFrame'));
assert(isempty(i) || isscalar(i));
endArgs = trackArgs(i:i+1);
trackArgs(i:i+1,:) = [];
if numel(endArgs)==2 && ischar(endArgs{2})
  endArgs{2} = str2double(endArgs{2});
end

tfStartEnd = numel(startArgs)==2 && numel(endArgs)==2;
if tfStartEnd
  frms = startArgs{2}:endArgs{2};
  tm = MFTSet(MovieIndexSetVariable.CurrMov,FrameSetFixed(frms),...
    FrameDecimationFixed.EveryFrame,TargetSetVariable.AllTgts);
else
  tm = MFTSetEnum.CurrMovAllTgtsEveryFrame;
end
lObj.trackAndExport(tm,'trackArgs',trackArgs,trkFilenameArgs{:});