function info = CombineSplitTracking(lblFile,infoFile,outTrkFile)

fid = fopen(infoFile,'r');

fns = {'jobi','movieFile','trxFile','startFrame','endFrame','jobid','rawtrkname','shfile','logfile'};
info = [];
while true,
  s = fgetl(fid);
  if ~ischar(s),
    break;
  end
  s = strtrim(s);
  if isempty(s),
    continue;
  end
  if s(1) == '#',
    continue;
  end
  ss = regexp(s,',','split');
  assert(numel(ss)==numel(fns));
  infocurr = cell2struct(ss,fns,2);
  infocurr.jobi = str2double(infocurr.jobi);
  infocurr.startFrame = str2double(infocurr.startFrame);
  infocurr.endFrame = str2double(infocurr.endFrame);
  info = structappend(info,infocurr);
end
fclose(fid);

ldata = load(lblFile,'projMacros','-mat');
[~,ldata.projMacros.projfile] = fileparts(lblFile);

fprintf('Tracking split into %d jobs.\n',numel(info));

isdone = false(1,numel(info));
for i = 1:numel(info),
  
  [rescurr,info(i).trkFile] = CheckJobStatus(info(i),ldata.projMacros); %#ok<AGROW>
  isdone(i) = rescurr.istrkfile;
  fprintf('%s, job %d = %s, frames %d to %d:\n  Script file %s ',...
    info(i).movieFile,info(i).jobi,info(i).jobid,...
    info(i).startFrame,info(i).endFrame,...
    info(i).shfile);
  if rescurr.isshfile,
    fprintf('EXISTS\n');
  else
    fprintf('DOES NOT EXIST\n');
  end
  fprintf('  Log file %s ',info(i).logfile);
  if rescurr.islogfile,
    fprintf('EXISTS\n');
  else
    fprintf('DOES NOT EXIST\n');
  end
  fprintf('  Output track file %s ',info(i).trkFile);
  if rescurr.istrkfile,
    fprintf('EXISTS\n');
  else
    fprintf('DOES NOT EXIST\n');
  end
  info(i).isshfile = rescurr.isshfile; %#ok<AGROW>
  info(i).islogfile = rescurr.islogfile; %#ok<AGROW>
  info(i).istrkfile = rescurr.istrkfile; %#ok<AGROW>
end

if ~all(isdone),
  fprintf('\n\nNot all jobs are completed. Cannot combine. Tails of log files for incomplete jobs.\n');
  for i = find(~isdone),
    if info(i).islogfile,
      fprintf('\n%s, job %d = %s, frames %d to %d:\nLog file %s:\n',...
        info(i).movieFile,info(i).jobi,info(i).jobid,...
        info(i).startFrame,info(i).endFrame,...
        info(i).logfile);
      system(sprintf('tail %s',info(i).logfile));
    end
  end
  return;
end

fprintf('All jobs are complete! Combining!\n');
for i = 1:numel(info),
  tdcurr = load(info(i).trkFile,'-mat');
  nFramesCurr = info(i).endFrame-info(i).startFrame+1;
  fractrked = nnz(sum(sum(sum(~isnan(tdcurr.pTrk(:,:,info(i).startFrame:info(i).endFrame,:)),1),2),4)>0) / nFramesCurr;
  if fractrked < 1,
    warning('Job %d: %d / %d frames have no tracking data',i,(1-fractrked)*nFramesCurr,nFramesCurr);
  end
  if i == 1,
    td = tdcurr;
  else
    fracprevtrked = nnz(sum(sum(sum(~isnan(td.pTrk(:,:,info(i).startFrame:info(i).endFrame,:)),1),2),4)>0) / nFramesCurr;
    if fracprevtrked > 0,
      warning('Job %d: %d / %d frames had been tracked in a previous job, overwriting.',i,fracprevtrked*nFramesCurr,nFramesCurr);
    end
    td.pTrk(:,:,info(i).startFrame:info(i).endFrame,:) = tdcurr.pTrk(:,:,info(i).startFrame:info(i).endFrame,:);
    td.pTrkTS(:,info(i).startFrame:info(i).endFrame,:) = tdcurr.pTrkTS(:,info(i).startFrame:info(i).endFrame,:);
    td.pTrkTag(:,info(i).startFrame:info(i).endFrame,:) = tdcurr.pTrkTag(:,info(i).startFrame:info(i).endFrame,:);
    if size(tdcurr.pTrkFull,4) > 0,
      td.pTrkFull(:,:,:,info(i).startFrame:info(i).endFrame) = tdcurr.pTrkFull(:,:,:,info(i).startFrame:info(i).endFrame);
    end
  end
end
isTracked = sum(sum(sum(~isnan(td.pTrk),1),2),4)>0;
fprintf('Saving tracking for %d frames between %d and %d to %s...\n',nnz(isTracked),...
  find(isTracked,1,'first'),find(isTracked,1,'last'),outTrkFile);
save(outTrkFile,'-struct','td');

function [res,trkfile] = CheckJobStatus(infocurr,projMacros)

res = struct;
res.isshfile = exist(infocurr.shfile,'file');
res.islogfile = exist(infocurr.logfile,'file');
[~,projMacros.movfile] = fileparts(infocurr.movieFile);
[~,projMacros.trxfile] = fileparts(infocurr.trxFile);
trkfile = [unMacroize(infocurr.rawtrkname,projMacros),'.trk'];
res.istrkfile = exist(trkfile,'file');

function s = unMacroize(s,projMacros)

macros = fieldnames(projMacros);
for i = 1:numel(macros),
  s = strrep(s,['$',macros{i}],projMacros.(macros{i}));
end
