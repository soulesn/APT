%% OBSOLETE SEE HPOptim.m

%% Compile xv results over rounds
nE = 3135;
nH = 3252;
nPch = 39;
npts = 17;
xverrE = nan(nE,npts,nPch,0);
xverrH = nan(nH,npts,nPch,0);
pchsE = cell(0,nPch);
pchsH = cell(0,nPch);
xvresE = cell(nPch,0);
xvresH = cell(nPch,0);

[xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
  'pch00','easy_outerfold01/rnd0',...
  'xv_prm0_%s_2018*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm0_20180808T184152.mat');
[xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres( ...
  'pch00','hard_outerfold01/rnd0',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm0_%s_20180808*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm0_20180808T184738.mat');

[xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
  'pch01','easy_outerfold01/rnd1',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm1_%s_20180808*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm1_20180808T210930.mat');
[xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres( ...
  'pch01','hard_outerfold01/rnd1',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm1_%s_20180808*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm1_20180808T211035.mat');

[xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
  'pch02','easy_outerfold01/rnd2',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm2_%s_20180809*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm2_20180809T094958.mat');
[xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres( ...
  'pch02','hard_outerfold01/rnd2',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm2_%s_20180809*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm2_20180809T095206.mat');

[xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
  'pch03','easy_outerfold01/rnd3',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm3_%s_20180809T*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm3_20180809T131757.mat');
[xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres( ...
  'pch03','hard_outerfold01/rnd3',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm3_%s_20180809T*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm3_20180809T132025.mat');

[xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
  'pch04','easy_outerfold01/rnd4',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm4_%s_20180810T*',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_easy_fold01_tblTrn_arhpo_outer3_easy_fold01_inner3_prm4_20180810T144753.mat');
[xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres( ...
  'pch04','hard_outerfold01/rnd4',...
  'xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm4_%s_20180810T*.mat',...
  'xvbase','xv_multitarget_bubble_expandedbehavior_20180425_cached_trainedToy_arhpo_outer3_hard_fold01_tblTrn_arhpo_outer3_hard_fold01_inner3_prm4_20180810T145011.mat');

% 
% [xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
%   'pch2_20180715','rnd03_easy_fold1',...
%   'xv_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_inner3_prm2_20180715_%s_201807*.mat',...
%   'xvbase','xv_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_inner3_prm2_20180715_20180715T212002.mat');
% [xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres(...
%   'pch2_20180715','rnd03_hard_fold1',...
%   'xv_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_inner3_prm2_20180715_%s_201807*.mat',...
%   'xvbase','xv_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_inner3_prm2_20180715_20180715T212108.mat');
% 
% [xverrE(:,:,:,end+1),pchsE(end+1,:),xvresE(:,end+1)] = HPOptim.loadXVres(...
%   'pch3_20180716','rnd04_easy_fold1',...
%   'xv_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_inner3_prm3_20180716_%s_201807*.mat',...
%   'xvbase','xv_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_inner3_prm3_20180716_20180716T182048.mat');
% [xverrH(:,:,:,end+1),pchsH(end+1,:),xvresH(:,end+1)] = HPOptim.loadXVres(...
%   'pch3_20180716','rnd04_hard_fold1',...
%   'xv_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_inner3_prm3_20180716_%s_201807*.mat',...
%   'xvbase','xv_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_inner3_prm3_20180716_20180716T202115.mat');
% 
%%
nRounds = size(xverrE,4);
isequal(pchsE,pchsH,repmat(pchsE(1,:),nRounds,1))
pchs = pchsE(1,:)';
size(xverrE)
size(xverrH)

%% scores by round

%% compare best pchs
clc
IRND = 5;
NBEST = 15;
tblres{IRND,1}(1:NBEST,:)
tblres{IRND,2}(1:NBEST,:)

tE = tblres{IRND,1}(1:NBEST,{'score' 'nptimprovedfull' 'pch'});
tH = tblres{IRND,2}(1:NBEST,{'score' 'nptimprovedfull' 'pch'});
tE.Properties.VariableNames{2} = 'nptimp';
tH.Properties.VariableNames{2} = 'nptimp';
tE
tH


%%
%HPOptim.genNewPrmFile('prm0_20180713.mat','prm1_20180714.mat','pch01',...
%  {'TwoLMRad_up';'FernsDepth_up2'});
% HPOptim.genNewPrmFile('prm1_20180714.mat','prm2_20180715.mat',...
%   'pch1_20180714',{'NumMajorIter_up';'RegFactor_dn'})
HPOptim.genNewPrmFile('prm2_20180715.mat','prm3_20180716.mat',...
  'pch2_20180715',{'FernThresholdRad_dn'})

%%
% HPOptim.genAndWritePchs('prm1_20180714.mat','pch1_20180714',{});
% HPOptim.genAndWritePchs('prm2_20180715.mat','pch2_20180715',{});
HPOptim.genAndWritePchs('prm3_20180716.mat','pch3_20180716',{});

%% No-patch xv err
%% No-patch xv, round 3. Label Date?

EASYTBLTRN = 'arhpo_outer3_easy_fold01_tblTrn.mat';
HARDTBLTRN = 'arhpo_outer3_hard_fold01_tblTrn.mat';
tblTrnE = loadSingleVariableMatfile(EASYTBLTRN);
tblTrnH = loadSingleVariableMatfile(HARDTBLTRN);
isequal(tblTrnE,xvresE{1,1}.xvRes(:,MFTable.FLDSID),...
  xvresE{1,2}.xvRes(:,MFTable.FLDSID),...
  xvresE{1,3}.xvRes(:,MFTable.FLDSID))
isequal(tblTrnH,xvresH{1,1}.xvRes(:,MFTable.FLDSID),...
  xvresH{1,2}.xvRes(:,MFTable.FLDSID),...
  xvresH{1,3}.xvRes(:,MFTable.FLDSID))
tblTrnAll = loadSingleVariableMatfile('tblTrn4703.mat');
ts0 = datenum('20171031T000000','yyyymmddTHHMMSS');
assert(isequal( any(tblTrnAll.pTS<ts0,2), all(tblTrnAll.pTS<ts0,2) ) );
tblTrnAll.pTSearly = all(tblTrnAll.pTS<ts0,2);

tblTrnE = innerjoin(tblTrnE,tblTrnAll,'Keys',MFTable.FLDSID,'RightVariables','pTSearly');
tblTrnH = innerjoin(tblTrnH,tblTrnAll,'Keys',MFTable.FLDSID,'RightVariables','pTSearly');
tfEarlyE = tblTrnE.pTSearly;
nEarlyE = nnz(tfEarlyE);
nLateE = nnz(~tfEarlyE);
tfEarlyH = tblTrnH.pTSearly;
nEarlyH = nnz(tfEarlyH);
nLateH = nnz(~tfEarlyH);

iNOPATCH = 1;
PTILES = [50 75 90 95 97.5 99];
IPTSPLOT = [9 11 12:17];
nptsPlot = numel(IPTSPLOT);
assert(all(strcmp(pchsE(:,iNOPATCH),'NOPATCH')));
assert(all(strcmp(pchsH(:,iNOPATCH),'NOPATCH')));
xverrE_early_NP = reshape(xverrE(tfEarlyE,IPTSPLOT,iNOPATCH,:),nEarlyE,nptsPlot,1,1,nRounds);
xverrE_late_NP = reshape(xverrE(~tfEarlyE,IPTSPLOT,iNOPATCH,:),nLateE,nptsPlot,1,1,nRounds);
xverrH_early_NP = reshape(xverrH(tfEarlyH,IPTSPLOT,iNOPATCH,:),nEarlyH,nptsPlot,1,1,nRounds);
xverrH_late_NP = reshape(xverrH(~tfEarlyH,IPTSPLOT,iNOPATCH,:),nLateH,nptsPlot,1,1,nRounds);

hFig = [];

hFig(end+1,1) = figure(11);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','EasyEarlyNoPatch');
GTPlot.ptileCurves(xverrE_early_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );

hFig(end+1,1) = figure(13);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','EasyLateNoPatch');
GTPlot.ptileCurves(xverrE_late_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );

hFig(end+1,1) = figure(21);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','HardEarlyNoPatch');
GTPlot.ptileCurves(xverrH_early_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );

hFig(end+1,1) = figure(23);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','HardLateNoPatch');
GTPlot.ptileCurves(xverrH_late_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );


assert(IPTSPLOT(5)==14);
leg14err = squeeze(xverrE_early_NP(:,5,1,1,:)); % nearlyE x 3. leg14 err, early/easy, over titrations
[~,idx] = sort(leg14err,'descend')
nWorstOnePct = round(nEarlyE * .01);
%%
  
  
iROUND = 3; % round 2
iNOPATCH = 1;
PTILES = [50 75 90 95 97.5 99];
IPTSPLOT = [9 11 12:17];
nptsPlot = numel(IPTSPLOT);
assert(all(strcmp(pchsE(:,iNOPATCH),'NOPATCH')));
assert(all(strcmp(pchsH(:,iNOPATCH),'NOPATCH')));
xverrE_NP = reshape(xverrE(:,IPTSPLOT,iNOPATCH,:),nE,nptsPlot,1,1,nRounds);
xverrH_NP = reshape(xverrH(:,IPTSPLOT,iNOPATCH,:),nH,nptsPlot,1,1,nRounds);


hFig = [];

hFig(end+1,1) = figure(11);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','EasyNoPatch');
GTPlot.ptileCurves(xverrE_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );

hFig(end+1,1) = figure(21);
hfig = hFig(end);
set(hfig,'Position',[1 41 1920 963],'name','HardNoPatch');
GTPlot.ptileCurves(xverrH_NP,...
  'ptiles',PTILES,......
  'hFig',hfig,...
  'axisArgs',{'XTicklabelRotation',45,'FontSize' 16}...
  );



%%

DOSAVE = false;
SAVEDIR = 'figs';
PTILES = [60 90];

xverrnormE = xverrE./median(xverrE(:,:,1),1);
xverrnormH = xverrH./median(xverrH(:,:,1),1);
xverrnormEmn = cat(2,mean(xverrnormE(:,1:5,:),2),mean(xverrnormE(:,6:10,:),2));
xverrnormHmn = cat(2,mean(xverrnormH(:,1:5,:),2),mean(xverrnormH(:,6:10,:),2));
assert(isequal(pchsE,pchsH));
pchNames = pchsE;

hFig = [];

hFig(5) = figure(15);
hfig = hFig(5);
set(hfig,'Name','easyzoom vw1','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(...
  xverrnormE(:,1:5,:),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(6) = figure(16);
hfig = hFig(6);
set(hfig,'Name','easyzoom vw2','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(...
  xverrnormE(:,6:10,:),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(7) = figure(17);
hfig = hFig(7);
set(hfig,'Name','hardzoom vw1','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(...
  xverrnormH(:,1:5,:),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(8) = figure(18);
hfig = hFig(8);
set(hfig,'Name','hardzoom vw2','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(...
  xverrnormH(:,6:10,:),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(9) = figure(19);
hfig = hFig(9);
set(hfig,'Name','easyzoom mean','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrnormEmn,'hFig',hfig,...
  'ptNames',{'vw1' 'vw2'},...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(10) = figure(20);
hfig = hFig(10);
set(hfig,'Name','hardzoom mean','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrnormHmn,'hFig',hfig,...
  'ptNames',{'vw1' 'vw2'},...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

if DOSAVE
  for i=1:numel(hFig)
    h = figure(hFig(i));
    fname = h.Name;
    hgsave(h,fullfile(SAVEDIR,[fname '.fig']));
    set(h,'PaperOrientation','landscape','PaperType','arch-d');
    print(h,'-dpdf',fullfile(SAVEDIR,[fname '.pdf']));  
    print(h,'-dpng','-r300',fullfile(SAVEDIR,[fname '.png']));   
    fprintf(1,'Saved %s.\n',fname);
  end
end

%%




PCHDIR = 'pch';
XVRESDIR = 'xvruns20180710';

dd = dir(fullfile(PCHDIR,'*.m'));
pchs = {dd.name}';
npch = numel(pchs);

for i=1:npch
  fprintf(1,'%s\n',pchs{i});
  type(fullfile(PCHDIR,pchs{i}));
end



%%
DOSAVE = false;
SAVEDIR = 'figs';
PTILES = [50 75 90 95 98];

xverrbasemedn = median(xverrE(:,:,1),1);
xverrnorm = xverrE./xverrbasemedn;
pchNames = pchsE;

hFig = [];
xverrplot = xverrnorm;
xverrplotmean = mean(xverrplot,2);

hFig(1) = figure(11);
hfig = hFig(1);
set(hfig,'Name','easyall','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(xverrplot(:,:,:,:,1),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(2) = figure(12);
hfig = hFig(2);
set(hfig,'Name','hardall','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(xverrplot(:,:,:,:,2),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(3) = figure(13);
hfig = hFig(3);
set(hfig,'Name','easymean','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(xverrplotmean(:,:,:,:,1),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(4) = figure(14);
hfig = hFig(4);
set(hfig,'Name','hardmean','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(xverrplotmean(:,:,:,:,2),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(5) = figure(15);
hfig = hFig(5);
set(hfig,'Name','easyzoom vw1','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrplot(:,:,1,:,1),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(6) = figure(16);
hfig = hFig(6);
set(hfig,'Name','easyzoom vw2','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrplot(:,:,2,:,1),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(7) = figure(17);
hfig = hFig(7);
set(hfig,'Name','hardzoom vw1','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrplot(:,:,1,:,2),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(8) = figure(18);
hfig = hFig(8);
set(hfig,'Name','hardzoom vw2','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurvesZoomed(xverrplot(:,:,2,:,2),'hFig',hfig,...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(9) = figure(19);
hfig = hFig(9);
set(hfig,'Name','easyzoom mean','Position',[2561 401 1920 1124]);
xvepm = squeeze(xverrplotmean);
[~,ax] = GTPlot.ptileCurvesZoomed(xvepm(:,:,:,1),'hFig',hfig,...
  'ptNames',{'vw1' 'vw2'},...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

hFig(10) = figure(20);
hfig = hFig(10);
set(hfig,'Name','hardzoom mean','Position',[2561 401 1920 1124]);
xvepm = squeeze(xverrplotmean);
[~,ax] = GTPlot.ptileCurvesZoomed(xvepm(:,:,:,2),'hFig',hfig,...
  'ptNames',{'vw1' 'vw2'},...
  'setNames',pchNames,...
  'ptiles',PTILES,...
  'ylimcapbase',true,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize' 8});

if DOSAVE
  for i=1:numel(hFig)
    h = figure(hFig(i));
    fname = h.Name;
    hgsave(h,fullfile(SAVEDIR,[fname '.fig']));
    set(h,'PaperOrientation','landscape','PaperType','arch-d');
    print(h,'-dpdf',fullfile(SAVEDIR,[fname '.pdf']));  
    print(h,'-dpng','-r300',fullfile(SAVEDIR,[fname '.png']));   
    fprintf(1,'Saved %s.\n',fname);
  end
end

