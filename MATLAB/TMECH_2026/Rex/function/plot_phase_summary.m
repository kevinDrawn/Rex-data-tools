function plot_phase_summary(phase_data, source)

data_types = ["angle","vel","torque","power"];
phase = phase_data.phase;

fig = figure;
tiledlayout(4,1);

for i = 1:4

    d = data_types(i);

    ax = nexttile;
    hold(ax,'on');

    % ===============================
    % 데이터 불러오기
    % ===============================
    muL = phase_data.results.(source).(d).left.mean;
    sdL = phase_data.results.(source).(d).left.std;

    muR = phase_data.results.(source).(d).right.mean;
    sdR = phase_data.results.(source).(d).right.std;

    % ===============================
    % Left (blue)
    % ===============================
    fill(ax, ...
        [phase fliplr(phase)], ...
        [muL+sdL fliplr(muL-sdL)], ...
        'b', 'FaceAlpha',0.2, 'EdgeColor','none');

    plot(ax, phase, muL, 'b','LineWidth',2);

    % ===============================
    % Right (red)
    % ===============================
    fill(ax, ...
        [phase fliplr(phase)], ...
        [muR+sdR fliplr(muR-sdR)], ...
        'r', 'FaceAlpha',0.2, 'EdgeColor','none');

    plot(ax, phase, muR, 'r','LineWidth',2);

    % ===============================
    % 스타일
    % ===============================
    title(ax, sprintf('%s (%s)', upper(d), upper(source)));    xlim(ax,[0 100]);
    grid(ax,'off');
    box off;

    % ===============================
    % y-label 정의
    % ===============================
    switch d
        case "angle"
            ylabel_str = 'Ankle angle (deg.)';
        case "vel"
            ylabel_str = 'Angular velocity (deg./s)';
        case "torque"
            ylabel_str = 'Torque (N·mm/kg)';
        case "power"
            ylabel_str = 'Power (W/kg)';
    end
    
    ylabel(ax, ylabel_str);

    if i == 4
        xlabel(ax,'Gait Phase (%)');
    end

end

legend({'Left ±std','Left','Right ±std','Right'}, ...
    'Location','bestoutside');

s = dbstack;
fprintf('[%s] Plotting clear = %s \r\n', s(1).name, source);

end