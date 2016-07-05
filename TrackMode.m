classdef TrackMode 
  properties
    prettyStringPat
    labelerProp
  end
  methods
    function obj = TrackMode(pspat,lprop)
      obj.prettyStringPat = pspat;
      obj.labelerProp = lprop;
    end
    function str = menuStr(obj,labelerObj)
      % Create pretty-string for UI
      lprop = obj.labelerProp;
      if isempty(lprop)
        str = obj.prettyStringPat;
      else
        val = labelerObj.(lprop);
        str = sprintf(obj.prettyStringPat,val);
      end
    end
    function [iMov,frms] = getMovsFramesToTrack(obj,labelerObj)
      if ~labelerObj.hasMovie
        iMov = zeros(0,1);
        frms = cell(0,1);
      else
        if obj==TrackMode.CurrMovNearCurrFrame
          iMov = labelerObj.currMovie;
          nf = labelerObj.nframes;
          currFrm = labelerObj.currFrame;
          df = labelerObj.(obj.labelerProp);
          frm0 = max(currFrm-df,1);
          frm1 = min(currFrm+df,nf);
          frms = {frm0:frm1};
        elseif obj==TrackMode.CurrMovEveryLblFrame
          iMov = labelerObj.currMovie;
          [~,nPts] = labelerObj.labelPosLabeledFramesStats();
          frms = {find(nPts>0)};
        elseif obj==TrackMode.CurrMovSelectedFrames
          iMov = labelerObj.currMovie;
          nf = labelerObj.nframes;
          frms = labelerObj.selectedFrames;
          assert(all(frms>0));
          tfOOB = frms>nf;
          if any(tfOOB)
            warning('TrackMode:oob',...
              'Ignoring %d out-of-bounds selected frames.',nnz(tfOOB));
          end
          frms = frms(~tfOOB);
          frms = {frms(:)'};
%         elseif obj==TrackMode.SelMovEveryLblFrame
%           iMov = labelerObj.moviesSelected;
%           nMov = numel(iMov);
%           frms = cell(nMov,1);
%           for i=1:nMov            
%           end
        else % track at regular intervals
          switch obj
            case TrackMode.CurrMovEveryFrame
              iMov = labelerObj.currMovie;
              df = 1;
            case {TrackMode.CurrMovEveryNFramesSmall TrackMode.CurrMovEveryNFramesLarge}
              iMov = labelerObj.currMovie;
              df = labelerObj.(obj.labelerProp);
            case TrackMode.SelMovEveryFrame
              iMov = labelerObj.moviesSelected;
              df = 1;
            case {TrackMode.SelMovEveryNFramesSmall TrackMode.SelMovEveryNFramesLarge}
              iMov = labelerObj.moviesSelected;
              df = labelerObj.(obj.labelerProp);
            case TrackMode.AllMovEveryFrame
              iMov = 1:labelerObj.nmovies;
              df = 1;
            case {TrackMode.AllMovEveryNFramesSmall TrackMode.AllMovEveryNFramesLarge}
              iMov = 1:labelerObj.nmovies;
              df = labelerObj.(obj.labelerProp);
            otherwise
              assert(false);
          end
          movIfoAll = labelerObj.movieInfoAll;
          frms = arrayfun(@(x)1:df:movIfoAll{x}.nframes,iMov,'uni',0);
        end                 
      end
    end
  end      
  enumeration
    CurrMovEveryFrame ('Current movie, every frame',[])
    CurrMovEveryLblFrame ('Current movie, every labeled frame',[])    
    CurrMovEveryNFramesSmall ('Current movie, every %d frames','trackNFramesSmall')
    CurrMovEveryNFramesLarge ('Current movie, every %d frames','trackNFramesLarge')
    CurrMovSelectedFrames ('Current movie, selected frames',[])
    CurrMovNearCurrFrame ('Current movie, within %d frames of current frame','trackNFramesNear')
    SelMovEveryFrame ('Selected movies, every frame',[])
    SelMovEveryNFramesSmall ('Selected movies, every %d frames','trackNFramesSmall')
    SelMovEveryNFramesLarge ('Selected movies, every %d frames','trackNFramesLarge')
    AllMovEveryFrame ('All movies, every frame',[])  
    AllMovEveryNFramesSmall ('All movies, every %d frames','trackNFramesSmall')
    AllMovEveryNFramesLarge ('All movies, every %d frames','trackNFramesLarge')
  end
end
    
    