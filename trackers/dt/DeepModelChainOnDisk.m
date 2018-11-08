classdef DeepModelChainOnDisk < handle
  properties
    rootDir % root/parent "Models" dir
    projID 
    netType % scalar DLNetType
    view % 0-based
    modelChainID % unique ID for a training model for (projname,view). 
                 % A model can be trained once, but also train-augmented.
    trainID % a single modelID may be trained multiple times due to 
            % train-augmentation, so a single modelID may have multiple
            % trainID associated with it.
    
    trainType % scalar DLTrainType
    iterFinal % final expected iteration    
  end
  properties (Dependent)
    dirProjLnx
    dirNetLnx
    dirViewLnx  
    dirModelChainLnx
    
    lblStrippedLnx % full path to stripped lbl file for this train session
    lblStrippedName % short filename 
    errfileLnx 
    errfileName
    trainLogLnx
    trainLogName
    killTokenLnx
    killTokenName
    trainDataLnx    
    trainFinalIndexLnx
    trainFinalIndexName    
  end
  methods
    function v = get.dirProjLnx(obj)
      v = [obj.rootDir '/' obj.projID];
    end
    function v = get.dirNetLnx(obj)
      v = [obj.rootDir '/' obj.projID '/' char(obj.netType)];
    end
    function v = get.dirViewLnx(obj)
      v = [obj.rootDir '/' obj.projID '/' char(obj.netType) '/' sprintf('view_%d',obj.view)];
    end
    function v = get.dirModelChainLnx(obj)
      v = [obj.rootDir '/' obj.projID '/' char(obj.netType) '/' sprintf('view_%d',obj.view) '/' obj.modelChainID];
    end
    
    function v = get.lblStrippedLnx(obj)      
      v = [obj.dirProjLnx '/' obj.lblStrippedName];      
    end
    function v = get.lblStrippedName(obj)
      v = sprintf('%s_%s.lbl',obj.modelChainID,obj.trainID);
    end
    function v = get.errfileLnx(obj)      
      v = [obj.dirProjLnx '/' obj.errfileName];      
    end
    function v = get.errfileName(obj)
      v = sprintf('%s_%s.err',obj.modelChainID,obj.trainID);
    end
    function v = get.trainLogLnx(obj)
      v = [obj.dirModelChainLnx '/' obj.trainLogName];
    end    
    function v = get.trainLogName(obj)
      v = sprintf('%s_%s.log',obj.trainID,lower(char(obj.trainType)));
    end    
    function v = get.killTokenLnx(obj)
      v = [obj.dirModelChainLnx '/' obj.killTokenName];
    end    
    function v = get.killTokenName(obj)
      v = sprintf('%s_%s.KILLED',obj.trainID,lower(char(obj.trainType)));
    end  
    function v = get.trainDataLnx(obj)
      v = [obj.dirModelChainLnx '/traindata.json'];
    end
    function v = get.trainFinalIndexLnx(obj)
      v = [obj.dirModelChainLnx '/' obj.trainFinalIndexName];
    end
    function v = get.trainFinalIndexName(obj)
      v = sprintf('deepnet-%d.index',obj.iterFinal);
    end
  end
  methods
    function obj = DeepModelChainOnDisk(varargin)
      for iprop=1:2:numel(varargin)
        obj.(varargin{iprop}) = varargin{iprop+1};
      end
    end
    function printall(obj)
      mc = metaclass(obj);
      props = mc.PropertyList;
      tf = [props.Dependent];
      propnames = {props(tf).Name}';
%       tf = cellfun(@(x)~isempty(regexp(x,'lnx$','once')),propnames);
%       propnames = propnames(tf);
      for i=1:numel(propnames)
        p = propnames{i};
        fprintf('%s: %s\n',p,obj.(p));
      end
    end
  end
end
    
  
  