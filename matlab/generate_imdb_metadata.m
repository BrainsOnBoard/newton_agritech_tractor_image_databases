function generate_imdb_metadata

num_databases = 2;
fps = 29.997;
f2get = { 'Ant_Lat', 'Ant_Long', 'Height' };
foutname = { 'latitude', 'longitude', 'height' };

if exist('gpsdata.mat','file')
    load('gpsdata.mat');
else
    gpsdata = {};
    for i = 1:num_databases
        [data,names] = dbfread(sprintf('route%d.dbf',i));
        for j = 1:length(f2get)
            vals = getdbffield(data,names,f2get{j});
            gpsdat.(foutname{j}) = vals;
        end

        vals = getdbffield(data,names,'Local_Time');
        t0 = str2secs(vals(1,:));
        gpsdat.time = [0; NaN(size(vals,1)-1,1)];
        for j = 2:size(vals,1)
            gpsdat.time(j) = str2secs(vals(j,:))-t0;
        end
        
        dates = getdbffield(data,names,'UTC_Date');
        gpsdat.rec_time = [dates(1,1:4) '-' dates(1,5:6) '-' dates(1,7:8) ' ' vals(1,1:8)];

        gpsdata{i} = gpsdat;
        clear gpsdat
    end
    save('gpsdata.mat','gpsdata');
end

for i = 1:num_databases
    dbdir = fullfile(mfiledir,'..',sprintf('route%d',i));
    num_files = numel(dir(fullfile(dbdir,'*.png')));
    vtime = (0:num_files-1)/fps;
    j = 1;
    num_files = [];
    while true
        fpath = sprintf('%s/frame%05d.png',dbdir,j);
        if ~exist(fpath,'file')
            break
        end
        
        ilo = find(vtime(j)>=gpsdata{i}.time,1,'last');
        
        % Delete image files recorded after GPS recording stopped
        if ilo == numel(gpsdata{i}.time)
            if isempty(num_files)
                num_files = j-1;
            end
            delete(fpath)
            j = j+1;
            continue
        end
        
        tlo = gpsdata{i}.time(ilo);
        prop = (vtime(j)-tlo)./(gpsdata{i}.time(ilo+1)-tlo);
        assert(prop >= 0 && prop < 1)

        latlo = gpsdata{i}.latitude(ilo);
        vlat(j) = latlo+prop*(gpsdata{i}.latitude(ilo+1)-latlo);

        lonlo = gpsdata{i}.longitude(ilo);
        vlon(j) = lonlo+prop*(gpsdata{i}.longitude(ilo+1)-lonlo);
        
        htlo = gpsdata{i}.height(ilo);
        vht(j) = htlo+prop*(gpsdata{i}.height(ilo+1)-htlo);
        
        j = j+1;
    end
    if isempty(num_files)
        num_files = j-1;
    end
    
    fid = fopen(fullfile(dbdir,'database_entries.csv'),'w');
    fprintf(fid,'X [mm], Y [mm], Z [mm], Heading [degrees], Filename\n');
    [vx,vy] = deg2utm(vlat,vlon);
    vx = (vx - min(vx)) * 1000; % to mm
    vy = (vy - min(vy)) * 1000;
    vhead = atan2d(diff(vx),diff(vy));
    vhead(end+1) = vhead(end);
    
    for j = 1:num_files
        fprintf(fid,'%.0f, %.0f, %.0f, %.3f, frame%05d.png\n',vx(j),vy(j),vht(j),vhead(j),j);
    end
    fclose(fid);
    
    fid = fopen(fullfile(dbdir,'database_metadata.yaml'),'w');
    fprintf(fid, ...
        ['%%YAML:1.0\n' ...
        '---\n' ...
        'metadata:\n' ...
        '   time: "%s"\n' ...
        '   type: route\n' ...
        '   camera:\n' ...
        '      name: pixpro_usb\n' ...
        '      resolution: [ 1280, 720 ]\n' ...
        '      isPanoramic: 0\n' ...
        '   needsUnwrapping: 0\n'],gpsdata{1}.rec_time);
    fclose(fid);
end

% figure(1);clf
% plot(gpsdata{1}.latitude,gpsdata{1}.longitude,gpsdata{2}.latitude,gpsdata{2}.longitude)

end

function secs=str2secs(str)
    secs = 60 * (60*str2double(str([1 2])) + str2double(str([4 5]))) + ...
           str2double(str([7 8])) + str2double(str(10))*0.1;
end

function out=getdbffield(data,names,whfield)
    out = cell2mat(data(:,strcmp(names,whfield)));
end
