function compareX0Methods(x, Y_matrix, x0_init)
% COMPAREX0METHODS Vergleicht Peakposition aus Pseudo-Voigt und Centroid
%
% EINGABE:
%   x         - x-Daten (Vektor)
%   Y_matrix  - y-Daten als Matrix (eine Spalte pro Datensatz)
%   x0_init   - Startwert Peaklage

    n = size(Y_matrix, 2);

    x0_voigt    = zeros(n, 1);
    err_voigt   = zeros(n, 1);
    x0_cent     = zeros(n, 1);
    err_cent    = zeros(n, 1);

    for i = 1:n
        fprintf('Verarbeite Datensatz %d / %d ...\n', i, n);

        % Pseudo-Voigt
        [p, e, ~] = fitPseudoVoigt(x, Y_matrix(:,i), x0_init);
        x0_voigt(i)  = p.x0;
        err_voigt(i) = e.x0;

        % Centroid
        [x0_cent(i), err_cent(i)] = fitCentroid(x, Y_matrix(:,i), x0_init);
    end

    idx = 1:n;

    % --- Plot ---
    figure('Color', 'white', 'Position', [100 100 900 500]);

    % Pseudo-Voigt
    errorbar(idx, x0_voigt, err_voigt, ...
        'ro-', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'MarkerFaceColor', 'r', 'DisplayName', 'Pseudo-Voigt');
    hold on;

    % Centroid
    errorbar(idx, x0_cent, err_cent, ...
        'bs--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'MarkerFaceColor', 'b', 'DisplayName', 'Centroid');

    % Differenz als Balken im Hintergrund
    diff_x0 = x0_voigt - x0_cent;
    yyaxis right;
    bar(idx, diff_x0, 0.4, 'FaceColor', [0.85 0.85 0.85], ...
        'EdgeColor', 'none', 'DisplayName', '\Deltax_0');
    yline(0, 'k:', 'LineWidth', 1);
    ylabel('\Deltax_0  (Voigt − Centroid)');
    set(gca, 'YColor', [0.5 0.5 0.5]);

    yyaxis left;
    ylabel('Peakposition x_0');
    xlabel('Datensatz');
    title('Vergleich Peakposition: Pseudo-Voigt vs. Centroid');
    legend('Location', 'best');
    grid on; box on;
    xticks(idx);
end