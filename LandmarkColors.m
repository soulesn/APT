function varargout = LandmarkColors(varargin)
% LANDMARKCOLORS MATLAB code for LandmarkColors.fig
%      LANDMARKCOLORS, by itself, creates a new LANDMARKCOLORS or raises the existing
%      singleton*.
%
%      H = LANDMARKCOLORS returns the handle to a new LANDMARKCOLORS or the handle to
%      the existing singleton*.
%
%      LANDMARKCOLORS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LANDMARKCOLORS.M with the given input arguments.
%
%      LANDMARKCOLORS('Property','Value',...) creates a new LANDMARKCOLORS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LandmarkColors_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LandmarkColors_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LandmarkColors

% Last Modified by GUIDE v2.5 08-Oct-2018 11:57:22

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @LandmarkColors_OpeningFcn, ...
                   'gui_OutputFcn',  @LandmarkColors_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1}) && exist(varargin{1}),
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

function handles = SetColorsFromColormap(handles)

handles.colors = handles.colormap;
for i = 1:handles.nlandmarks,
  set(handles.hbuttons(i),'BackgroundColor',handles.colors(i,:));
end

function handles = SetColormap(handles)

handles.colormap = feval(handles.colormapname,handles.nlandmarks);
if handles.brightness > .5,
  v = min(1,max(0,(handles.brightness-.5)*2));
  handles.colormap = handles.colormap*(1-v)+v;
elseif handles.brightness < .5,
  v = min(1,max(0,handles.brightness*2));
  handles.colormap = handles.colormap*v;
end

if ~isfield(handles,'colormapim'),
  handles.colormapim = imagesc(1:handles.nlandmarks,'Parent',handles.axes_colormap);
  axis(handles.axes_colormap,'off');
end
colormap(handles.axes_colormap,handles.colormap);

function handles = SaveState(handles)

handles.saved = struct('colors',handles.colors,'colormapname',handles.colormapname);

function [handles,success] = GuessBrightness(handles)

handles.brightness = .5;
success = false;
if isempty(handles.colors) || isempty(handles.colormapname),
  return;
end

colormap = feval(handles.colormapname,handles.nlandmarks);
ratio = handles.colors./colormap;
ratio(isnan(ratio)) = [];

% give up
if std(ratio(:)) > .02,
  return;
end

meanratio = mean(ratio);
if meanratio > 1,
  v = max(0,min(1,regress(handles.colors(:)-colormap(:),1-colormap(:))));
  newcolormap = (1-v)*colormap + v;
  err = abs(handles.colors(:)-newcolormap(:));
  if max(err) > .02,
    return;
  end
  handles.brightness = .5 + v/2;
elseif meanratio < 1,
  v = max(0,min(1,regress(handles.colors(:),colormap(:))));
  newcolormap = v*colormap;
  err = abs(handles.colors(:)-newcolormap(:));
  if max(err) > .02,
    return;
  end
  handles.brightness = v/2;
else
  handles.brightness = .5;
end
success = true;

% --- Executes just before LandmarkColors is made visible.
function LandmarkColors_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LandmarkColors (see VARARGIN)

% Choose default command line output for LandmarkColors
handles.output = hObject;

handles.colors = varargin{1};
handles.colormapname = varargin{2};
handles.nlandmarks = varargin{3};
% if nargin >= 4,
ti = varargin{4};
% else
%   ti = 'Landmark colors';
% end
set(handles.figure_landmarkcolors,'Name',ti);

handles.applyCbkFcn = varargin{5};
handles.saved = [];

% default
if isempty(handles.colormapname),
  handles.colormapname = 'jet';
end

% set colormap name in popup menu
s = get(handles.popupmenu_colormap,'String');
i = find(strcmpi(s,handles.colormapname),1);
if isempty(i),
  warning('Unknown colormap name %s, using default jet',handles.colormapname);
  handles.colormapname = 'jet';
  i = find(strcmpi(s,'jet'),1);
end
set(handles.popupmenu_colormap,'Value',i);

[handles,usecolormap] = GuessBrightness(handles);
set(handles.edit_brightness,'String',num2str(handles.brightness));
set(handles.slider_brightness,'Value',handles.brightness);

% store value
handles = SetColormap(handles);

% set colors based on colormap if not yet set
if isempty(handles.colors),
  handles.colors = handles.colormap;
end

% create buttons
w = 1/handles.nlandmarks;
borderfrac = .05;
for i = 1:handles.nlandmarks,
  
  handles.hbuttons(i) = uicontrol('style','pushbutton',...
    'ForegroundColor','k',...
    'BackgroundColor',handles.colors(i,:),...
    'Units','normalized',...
    'Position',[w*borderfrac+w*(i-1),borderfrac,w*(1-2*borderfrac),1-2*borderfrac],...
    'Parent',handles.uipanel_manual,...
    'Callback',@(hObject,eventdata)LandmarkColors('pushbutton_manual_Callback',hObject,eventdata,guidata(hObject),i),...
    'Tag',sprintf('pushbutton_manual_%d',i),...
    'String',num2str(i));

end

% set by default to manual
set(handles.radiobutton_manual,'Value',~usecolormap);
set(handles.radiobutton_colormap,'Value',usecolormap);
handles = UpdateMode(handles);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes LandmarkColors wait for user response (see UIRESUME)
uiwait(handles.figure_landmarkcolors);

function handles = UpdateMode(handles)

v = get(handles.radiobutton_manual,'Value');
hcm = findobj(handles.uipanel_colormap,'-property','Enable');
hm = findobj(handles.uipanel_manual,'-property','Enable');
if v == 1,
  set(hcm,'Enable','off');
  set(hm,'Enable','on');
else
  set(hcm,'Enable','on');
  set(hm,'Enable','off');
end

% --- Outputs from this function are returned to the command line.
function varargout = LandmarkColors_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles),
  warning('State lost');
  varargout{1} = false;
  varargout{2} = [];
  varargout{3} = '';
else
  if isempty(handles.saved),
    varargout{1} = false;
    varargout{2} = [];
    varargout{3} = '';
  else
    varargout{1} = true;
    varargout{2} = handles.saved.colors;
    varargout{3} = handles.saved.colormapname;
  end
  delete(handles.figure_landmarkcolors);
end

% --- Executes on selection change in popupmenu_colormap.
function popupmenu_colormap_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu_colormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu_colormap contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu_colormap

contents = cellstr(get(hObject,'String'));
handles.colormapname = contents{get(hObject,'Value')};
handles = SetColormap(handles);
handles = SetColorsFromColormap(handles);
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function popupmenu_colormap_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_colormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_editcolormap.
function pushbutton_editcolormap_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_editcolormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in pushbutton_resetcolormap.
function pushbutton_resetcolormap_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_resetcolormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton_apply.
function pushbutton_apply_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_apply (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles = SaveState(handles);
handles.applyCbkFcn(handles.colors,handles.colormapname);
guidata(hObject,handles);

% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uiresume(handles.figure_landmarkcolors);

% --- Executes on button press in pushbutton_done.
function pushbutton_done_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_done (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles = SaveState(handles);
guidata(hObject,handles);
uiresume(handles.figure_landmarkcolors);

function pushbutton_manual_Callback(hObject, eventdata, handles, landmarki)


fprintf('Landmark %d\n',landmarki);
handles.colors(landmarki,:) = uisetcolor(handles.colors(landmarki,:),sprintf('Landmark %d color',landmarki));
set(handles.hbuttons(landmarki),'BackgroundColor',handles.colors(landmarki,:));
guidata(hObject,handles);



% --- Executes on button press in radiobutton_colormap.
function radiobutton_colormap_Callback(hObject, eventdata, handles)
% hObject    handle to radiobutton_colormap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton_colormap
handles = UpdateMode(handles);
guidata(hObject,handles);


% --- Executes on button press in radiobutton_manual.
function radiobutton_manual_Callback(hObject, eventdata, handles)
% hObject    handle to radiobutton_manual (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton_manual
handles = UpdateMode(handles);
guidata(hObject,handles);


% --- Executes when user attempts to close figure_landmarkcolors.
function figure_landmarkcolors_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure_landmarkcolors (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
uiresume(handles.figure_landmarkcolors);


% --- Executes on slider movement.
function slider_brightness_Callback(hObject, eventdata, handles)
% hObject    handle to slider_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
v = get(hObject,'Value');
handles.brightness = v;
set(handles.edit_brightness,'String',num2str(v));
handles = SetColormap(handles);
handles = SetColorsFromColormap(handles);
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function slider_brightness_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function edit_brightness_Callback(hObject, eventdata, handles)
% hObject    handle to edit_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_brightness as text
%        str2double(get(hObject,'String')) returns contents of edit_brightness as a double
v = str2double(get(hObject,'String'));
if isnan(v) || v < 0 || v > 1,
  warndlg('Brightness must be a number between 0 and 1','Error setting brightness','modal');
  set(hObject,'String',num2str(handles.brightness));
else
  handles.brightness = v;
  set(handles.slider_brightness,'Value',v);
  handles = SetColormap(handles);
  handles = SetColorsFromColormap(handles);
  guidata(hObject,handles);
end


% --- Executes during object creation, after setting all properties.
function edit_brightness_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
