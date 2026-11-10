function config = Mocap_HallConfig()
    %MOCAP_HALLCONFIG Motion capture angle and synchronization signals.
    config.ProjectType = 'Mocap_Hall';
    config.Fields = {'Time'; 'mocap_angle'; 'sync_state'};
    config.OptionalFields = cell(0, 1);
end
