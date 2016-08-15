classdef LabelCoreSeq < LabelCore   
  % Label mode 1 (Sequential)
  %
  % There are three labeling states: 'label', 'adjust', 'accepted'.
  %
  % During the labeling state, points are being clicked in order. This
  % includes the state where there are zero points clicked (fresh image).
  %
  % During the adjustment state, points may be adjusted by click-dragging.
  %
  % When any/all adjustment is complete, tbAccept is clicked and we enter
  % the accepted stage. This locks the labeled points for this frame and
  % writes to .labeledpos.
  %
  % pbClear is enabled at all times. Clicking it returns to the 'label'
  % state and clears any labeled points.
  %
  % tbAccept is disabled during 'label'. During 'adjust', its name is
  % "Accept" and clicking it moves to the 'accepted' state. During
  % 'accepted, its name is "Adjust" and clicking it moves to the 'adjust'
  % state.
  %
  % When multiple targets are present, all actions/transitions are for
  % the current target. Acceptance writes to .labeledpos for the current
  % target. Changing targets is like changing frames; all pre-acceptance
  % actions are discarded.
  %
  % Occluded. In the 'label' state, pnl-Clicking sets the current point to
  % be occluded. In the 'adjust' state, there is currently no way to a)
  % make an occluded point non-occluded, or make a non-occluded point
  % occluded. 

  properties
    supportsMultiView = false;
	supportsCalibration = false;
  end
        
  properties
    iPtMove;
    nPtsLabeled; % scalar integer. 0..nPts, or inf.
  end
  
  methods
    
    function obj = LabelCoreSeq(varargin)
      obj = obj@LabelCore(varargin{:});
    end
    
    function newFrame(obj,iFrm0,iFrm1,iTgt) %#ok<INUSL>
      obj.newFrameTarget(iFrm1,iTgt);
    end
    
    function newTarget(obj,iTgt0,iTgt1,iFrm) %#ok<INUSL>
      obj.newFrameTarget(iFrm,iTgt1);
    end
    
    function newFrameAndTarget(obj,~,iFrm1,~,iTgt1)
      obj.newFrameTarget(iFrm1,iTgt1);
    end
    
    function clearLabels(obj)
      obj.beginLabel();
    end
    
    function acceptLabels(obj)
      obj.beginAccepted(true);
    end
    
    function unAcceptLabels(obj)
      obj.beginAdjust();
    end
    
    function axBDF(obj,~,~)
      obj.axOrAxOccBDF(false);
    end
    
    function axOccBDF(obj,~,~)
      obj.axOrAxOccBDF(true);
    end
   
    function axOrAxOccBDF(obj,tfAxOcc)
      if obj.state==LabelState.LABEL
        ax = obj.hAx;
        
        nlbled = obj.nPtsLabeled;
        assert(nlbled<obj.nPts);
        i = nlbled+1;
        if tfAxOcc
          obj.tfOcc(i) = true;
          obj.refreshOccludedPts();
        else
          tmp = get(ax,'CurrentPoint');
          x = tmp(1,1);
          y = tmp(1,2);
          obj.assignLabelCoordsIRaw([x y],i);
        end
        obj.nPtsLabeled = i;
        if i==obj.nPts
          obj.beginAdjust();
        end
      end
    end
        
    function ptBDF(obj,src,~)
      switch obj.state
        case {LabelState.ADJUST LabelState.ACCEPTED}          
          iPt = get(src,'UserData');
          if obj.state==LabelState.ACCEPTED
            obj.beginAdjust();
          end
          obj.iPtMove = iPt;
      end
    end
    
    function wbmf(obj,~,~)
      if obj.state==LabelState.ADJUST
        iPt = obj.iPtMove;
        if ~isnan(iPt)
          ax = obj.hAx;
          tmp = get(ax,'CurrentPoint');
          pos = tmp(1,1:2);
          set(obj.hPts(iPt),'XData',pos(1),'YData',pos(2));
          pos(1) = pos(1) + obj.DT2P;
          set(obj.hPtsTxt(iPt),'Position',pos);
        end
      end
    end
    
    function wbuf(obj,~,~)
      if obj.state==LabelState.ADJUST
        obj.iPtMove = nan;
      end
    end
    
    function tfKPused = kpf(obj,~,evt)
      key = evt.Key;
      modifier = evt.Modifier;
      tfCtrl = ismember('control',modifier);
      
      tfKPused = true;
      if strcmp(key,'h') && tfCtrl
        obj.labelsHideToggle();
      elseif any(strcmp(key,{'s' 'space'})) && ~tfCtrl % accept
        if obj.state==LabelState.ADJUST
          obj.acceptLabels();
        end
      elseif any(strcmp(key,{'rightarrow' 'd' 'equal'}))
        obj.labeler.frameUp(tfCtrl);
      elseif any(strcmp(key,{'leftarrow' 'a' 'hyphen'}))
        obj.labeler.frameDown(tfCtrl);
      else
        tfKPused = false;
      end
    end
    
    function h = getLabelingHelp(obj) %#ok<MANU>
      h = { ...
        '* A/D, LEFT/RIGHT, or MINUS(-)/EQUAL(=) decrement/increment the frame shown.'
        '* <ctrl>+A/D, LEFT/RIGHT etc decrement/increment by 10 frames.'
        '* S or <space> accepts the labels for the current frame/target.'};
    end
          
  end
  
  methods
    
    function newFrameTarget(obj,iFrm,iTgt)
      % React to new frame or target. Set mode1 label state (.lbl1_*) 
      % according to labelpos. If a frame is not labeled, then start fresh 
      % in Label state. Otherwise, start in Accepted state with saved labels.
            
      [tflabeled,lpos] = obj.labeler.labelPosIsLabeled(iFrm,iTgt);
      if tflabeled
        obj.nPtsLabeled = obj.nPts;
        obj.assignLabelCoords(lpos);
        obj.iPtMove = nan;
        obj.beginAccepted(false); % I guess could just call with true arg
      else
        obj.beginLabel();
      end
    end
    
    function beginLabel(obj)
      % Enter Label state and clear all mode1 label state for current
      % frame/target
      
      set(obj.tbAccept,'BackgroundColor',[0.4 0.0 0.0],...
        'String','','Enable','off','Value',0);
      
      obj.assignLabelCoords(nan(obj.nPts,2));
      obj.nPtsLabeled = 0;
      obj.iPtMove = nan;
      obj.labeler.labelPosClear();
      
      obj.state = LabelState.LABEL;      
    end
       
    function beginAdjust(obj)
      % Enter adjustment state for current frame/target
      
      assert(obj.nPtsLabeled==obj.nPts);
            
      obj.iPtMove = nan;
      
      set(obj.tbAccept,'BackgroundColor',[0.6,0,0],'String','Accept',...
        'Value',0,'Enable','on');
      obj.state = LabelState.ADJUST;
    end
    
    function beginAccepted(obj,tfSetLabelPos)
      % Enter accepted state (for current frame)
      
      if tfSetLabelPos
        xy = obj.getLabelCoords();
        obj.labeler.labelPosSet(xy);
      end
      set(obj.tbAccept,'BackgroundColor',[0,0.4,0],'String','Accepted',...
        'Value',1,'Enable','on');
      obj.state = LabelState.ACCEPTED;
    end    
    
  end
  
end