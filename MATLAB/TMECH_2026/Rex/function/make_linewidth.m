
function lw = make_linewidth(s, cfg)

    % 기본값
    if ~isfield(cfg,'lw_min'), cfg.lw_min = 0.1; end
    if ~isfield(cfg,'lw_max'), cfg.lw_max = 4; end
    if ~isfield(cfg,'lw_gamma'), cfg.lw_gamma = 1.0; end

    % normalize
    s_norm = (s - min(s)) / max(eps, (max(s) - min(s)));

    % 강조
    s_weight = s_norm .^ cfg.lw_gamma;

    % scale
    lw = cfg.lw_min + (cfg.lw_max - cfg.lw_min) * s_weight;

end