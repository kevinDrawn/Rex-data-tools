function sim = compute_cycloid_iou(x1, y1, x2, y2)

    % --- normalization (선택 but 추천) ---
    x_all = [x1, x2];
    y_all = [y1, y2];
    
    xmin = min(x_all); xmax = max(x_all);
    ymin = min(y_all); ymax = max(y_all);

    % --- grid ---
    res = 500;   % 500~1000 추천
    [xq, yq] = meshgrid( ...
        linspace(xmin, xmax, res), ...
        linspace(ymin, ymax, res));

    % --- mask ---
    mask1 = inpolygon(xq, yq, x1, y1);
    mask2 = inpolygon(xq, yq, x2, y2);

    % --- IoU ---
    inter = sum(mask1 & mask2, 'all');
    uni   = sum(mask1 | mask2, 'all');

    sim = inter / uni * 100;
end