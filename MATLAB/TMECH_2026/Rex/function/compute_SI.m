function SI = compute_SI(L, R)

n = min(numel(L), numel(R));

L = L(1:n);
R = R(1:n);

SI = (L - R) ./ (0.5*(L + R)) * 100;
end