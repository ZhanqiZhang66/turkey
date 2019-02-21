clear all;
clc;
close all;

global img_cache;
img_cache = {};

% read table
T = readtable('sample_result.csv','Delimiter',',','ReadVariableNames',false);

row = 1;
f = figure; 
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
guidata(f, struct('row', row, 'result_table', T));
show_ann(T, row);
set(gcf, 'Units', 'pixels');
figure_size = get(gcf, 'position');
figure_width = figure_size(3);
zone_width = 0.2 * figure_width;
button_width = 0.15 * figure_width;
buffer_width = 0.025 * figure_width;
previous_pb = uicontrol(f,'Style','pushbutton','String','Previous',...
    'Position',[buffer_width 20 button_width 40],'ForegroundColor','white',...
    'BackgroundColor',[65, 172, 244]/255,'FontSize',14,'Callback',@previous_callback);
next_pb = uicontrol(f,'Style','pushbutton','String','Next',...
    'Position',[zone_width+buffer_width 20 button_width 40],'ForegroundColor','white',...
    'BackgroundColor',[65, 172, 244]/255,'FontSize',14,'Callback',@next_callback);
approve_pb = uicontrol(f,'Style','pushbutton','String','Approve',...
    'Position',[2*zone_width+buffer_width 20 button_width 40],'ForegroundColor','white',...
    'BackgroundColor',[65, 244, 97]/255,'FontSize',14,'Callback',@approve_callback);
reject_pb = uicontrol(f,'Style','pushbutton','String','Reject',...
    'Position',[3*zone_width+buffer_width 20 button_width 40],'ForegroundColor','white',...
    'BackgroundColor',[244, 65, 65]/255,'FontSize',14,'Callback',@reject_callback);
finish_pb = uicontrol(f,'Style','pushbutton','String','Finish and Export',...
    'Position',[4*zone_width+buffer_width 20 button_width 40],'ForegroundColor','white',...
    'BackgroundColor',[255, 177, 68]/255,'FontSize',14,'Callback',@finish_callback);

function next_callback(hObject, eventdata, handles)
    % get data from figure handle
    data = guidata(hObject);
    T = data.result_table;
    row = data.row;
    row = row + 1;
    show_ann(T, row);
    guidata(hObject, struct('row', row, 'result_table', T));
end

function previous_callback(hObject, eventdata, handles)
    data = guidata(hObject);
    T = data.result_table;
    row = data.row;
    row = row - 1;
    show_ann(T, row);
    guidata(hObject, struct('row', row, 'result_table', T));
end

function approve_callback(hObject, eventdata, handles)
    data = guidata(hObject);
    T = data.result_table;
    row = data.row;
    T(row, 32) = {'x'};
    T(row, 33) = {''};
    guidata(hObject, struct('row', row, 'result_table', T));
end

function reject_callback(hObject, eventdata, handles)
    data = guidata(hObject);
    T = data.result_table;
    row = data.row;
    T(row, 32) = {''};
    T(row, 33) = {'rejected'};
    guidata(hObject, struct('row', row, 'result_table', T));
end

function finish_callback(hObject, eventdata, handles)
    data = guidata(hObject);
    T = data.result_table;
    result_to_csv(T, 'review.csv');
    close gcf;
end

function show_ann(T, row)
    global img_cache;
    
    row = mod(row, size(T, 1));
    if (row == 0)
       row = 1; 
    end
    % get class name, img url, and annotation JSON struct
    class_names = strjoin(cellstr(table2cell(T(row, 30))));
    class_names = split(class_names, '-');
    class_num = length(class_names);
    img_url = strjoin(cellstr(table2cell(T(row, 28))));
    ann = jsondecode(strjoin(cellstr(table2cell(T(row, 31)))));

    % get cached image or download image from img url
    if (length(img_cache) < row)
        option = weboptions('Timeout', 10);
        img = webread(img_url, option);
        img_cache{end+1} = img;
    else
        img = img_cache{row};
    end

    % calculate the ratio between original image and the one displayed on Amazon MTurk
    ratio = size(img, 2)/1000;
    % hash class names and generate repeatable class colors
    colors = ones([class_num, 3]);
    for i = 1:class_num
       val = myHash(class_names{i}); 
       rng(val);
       hue = rand();
       hsv = [hue, 0.73, 1];
       colors(i, :) = hsv2rgb(hsv);
    end

    % display annotations as filled transparent polygons. Only supports polygons right now. 
    % TODO: Add support for dots and links. 
    for i = 1:size(ann, 1)
        if (strcmp(ann(i).mode, 'polygon'))
            coordinates = [];
            for j = 1:size(ann(i).data, 1)
                coordinates = [coordinates, ratio*ann(i).data(j, :)];
            end
            class_idx = 0;
            for j = 1:class_num
               if strcmp(ann(i).class, class_names(j))
                  class_idx = j; 
               end
            end
            img = insertShape(img, 'FilledPolygon', coordinates, 'Color', 255*colors(class_idx, :), 'Opacity', 0.5);
        end
    end
    imshow(img);
end

function [val] = myHash(input_string)
   out_string = mlreportgen.utils.hash(input_string);
   hex_string = dec2hex(char(out_string));
   whole_hex_string = "";
   for i = 2:4
       whole_hex_string = strcat(whole_hex_string, hex_string(i, :));
   end
   val = str2double(whole_hex_string);
end

function result_to_csv(T, filename)
    column_names = ["HITId","HITTypeId","Title","Description","Keywords","Reward",...
        "CreationTime","MaxAssignments","RequesterAnnotation","AssignmentDurationInSeconds",...
        "AutoApprovalDelayInSeconds","Expiration","NumberOfSimilarHITs","LifetimeInSeconds",...
        "AssignmentId","WorkerId","AssignmentStatus","AcceptTime","SubmitTime","AutoApprovalTime",...
        "ApprovalTime","RejectionTime","RequesterFeedback","WorkTimeInSeconds","LifetimeApprovalRate",...
        "Last30DaysApprovalRate","Last7DaysApprovalRate","Input.img_url","Input.annotation_mode",...
        "Input.classes","Answer.coordinates","Approve","Reject"];
    fid = fopen(filename,'w');
    format_string = "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n";
    fprintf(fid,format_string,column_names);
    for i = 1:size(T, 1)
        temp_string = T(i, :).Variables;
        fprintf(fid,format_string,process_cell(temp_string));
    end
    fclose(fid);
end

function b = process_cell(a)
    b = [];
    for i = 1:length(a)
       b = [b, string(escape_quote(a{i}))]; 
    end
end

function b = escape_quote(a)
    b = '';
    idx = 1;
    need_quotation = 0;
    for i = 1:length(a)
        b(idx) = a(i);
        if (a(i) == '"')
            need_quotation = 1;
            b = strcat(b, '""');
            idx = idx + 1;
        end
        idx = idx + 1;
    end
    if need_quotation == 1
       b = strcat('"', b, '"'); 
    end
end