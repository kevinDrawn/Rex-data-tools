function config = StanceConfig()
    %STANCECONFIG Source video frames, seconds, and hind-paw gait labels.
    config.ProjectType = 'Stance';
    config.Fields = {'Time'; 'frame'; 'IC'; 'TO'; 'stance'};
    config.OptionalFields = cell(0, 1);
end
