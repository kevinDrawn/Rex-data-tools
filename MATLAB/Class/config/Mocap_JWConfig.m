function config = Mocap_JWConfig()
    %MOCAP_JWCONFIG Toe and optional ilium-marker X/Y coordinates (mm) and video time (seconds).
    config.ProjectType = 'Mocap_JW';
    config.Fields = {'Time'; 'TO_x'; 'TO_y'};
    % Preserve CSV timestamps when the shared video-frame time replaces Time.
    config.OptionalFields = {'TimeCSV'; 'TO_x_filtered'; 'TO_y_filtered'; ...
        'IL_x'; 'IL_y'; 'IL_x_filtered'; 'IL_y_filtered'};
end
