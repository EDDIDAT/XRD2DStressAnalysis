function Peakhandles = CalcPeakPositions2DXRD(ElementalFormula,MPDFileName,twotheta,Emax)

    if strcmp(twotheta, 'ETA3000')
        P.ElementalFormula = ElementalFormula;
        P.MPDFileName = MPDFileName;
        P.ShowSubstratePeaks = 0;
        
        [out, T] = CreateSampleEPostheo(P);

%         if strcmp(Measurement.Anode,'Cu')
            % T.lambdaka1 = 1.54056;
            % T.lambdaka2 = 1.54433;
            % Gallium K-alpha
            lambdaka1{1} = 1.340121; %1.34023;
            lambdaka2{1} = 1.344037;
            % Indium K-alpha
            lambdaka1{2} = 0.512128;
            lambdaka2{2} = 0.51656;
            % Indium K-beta
            lambdaka1{3} = 0.454558;
            lambdaka2{3} = 0.454558;

        for k = 1:size(lambdaka1,2)
            T.lambdaka1 = lambdaka1{k};
            T.lambdaka2 = lambdaka2{k};
%         elseif strcmp(Measurement.Anode,'Co')
%             T.lambdaka1 = 1.78897;
%             T.lambdaka2 = 1.79278;
%         elseif strcmp(Measurement.Anode,'Ag')
%             T.lambdaka1 = 0.55941;
%             T.lambdaka2 = 0.56380;
%         elseif strcmp(Measurement.Anode,'Fe')
%             T.lambdaka1 = 1.93579;
%             T.lambdaka2 = 1.93991;
%         elseif strcmp(Measurement.Anode,'Mo')
%             T.lambdaka1 = 0.70926;
%             T.lambdaka2 = 0.71354;
%         elseif strcmp(Measurement.Anode,'Cr')    
%             T.lambdaka1 = 2.28962;
%             T.lambdaka2 = 2.29351;
%         end

        % TwoTheta of measurement
%         T.twotheta = twotheta;
        % Info from material
        T.EMax = Emax;
        % Crystal structure of the material
        T.cs = T.Material.CrystalStructure;
        % Lattice parameter of the material
        T.a0 = T.Material.LatticeParameter;

        % Info from material
        T.dmin = 0.07;
        % Calculation of maximum hkl²
        if ~isempty(T.a0)
            T.hklquadratmax = (T.a0(1)/T.dmin)^2;
        else
            T.hklquadratmax = [];
        end
        
        T.Peaks_y = 100;
        % Create matrix for the line plot of the peak positions (Y values)
        T.Y1 = [0 T.Peaks_y nan];

%         % Calculation of the maximum peak intensities of the respecive spectrum
%         T.Peaks_y = zeros(length(T.Material),1);
%         % Find intensity maximum
%         for i = 1:length(T.Material)
%             T.Peaks_y(i,:) = max(DataTmp{i}(:, 2));
%         end
%         % Create matrix for the line plot of the peak positions (Y values)
%         for i = 1:length(T.Material)
%             T.Y1(i,:) = [0 T.Peaks_y(i) nan];
%         end
        
        %% Plot diffraction lines from T.Material
        % Calculation of peak positions for bcc materials
        if strcmp(T.cs,'bcc')
            % Calculation of all possible hkl combinations
            [T.h, T.k, T.l] = ndgrid(1:10, 0:9, 0:9);
            T.d = T.h+T.k+T.l;
            i = find(rem(T.d,2) == 0);
            T.p = [T.h(i),T.k(i),T.l(i)];
            % Use only hkl with hkl² < hkl²max
            for i=1:size(T.p,1)
                if (T.p(i,1)^2 + T.p(i,2)^2 + T.p(i,3)^2) <= T.hklquadratmax
                    T.y(i,:) = T.p(i,:);
                end
            end
            % delete zero rows
            T.y(all(T.y == 0,2),:)=[];
            % Use only hkl that are allowed for bcc materials
            for i=1:size(T.y,1)
                if T.y(i,1) >= T.y(i,2) && T.y(i,1) >= T.y(i,3) && T.y(i,2) >= T.y(i,3)
                   T.z(i,:) = T.y(i,:);
                end
            end
            % delete zero rows
            T.z(all(T.z == 0,2),:)=[];
            % Calculation of theoretical d spacings for the used hkl values
            for i = 1:size(T.z,1)
                T.dtheo(i,:) = T.a0/(sqrt(T.z(i,1)^2+T.z(i,2)^2+T.z(i,3)^2));
            end
        
            T.hkl = [T.z T.dtheo];
            % Sort columns in descending order
            T.hkl_sort = sortrows(T.hkl, -4);
            [C,ia,ic] = unique(T.hkl_sort(:,4),'rows','last');
            T.hkl_sort = T.hkl_sort(ia,1:4);
            T.hkl_sort = sortrows(T.hkl_sort, -4);
            % Calculation of theoreitcal energy positons for the used hkl values
            for i = 1:size(T.hkl_sort,1)
                Etheoka1_tmp(i,:) = 2.*asind(T.lambdaka1./(20.*T.hkl_sort(i,4)));
                Etheoka2_tmp(i,:) = 2.*asind(T.lambdaka2./(20.*T.hkl_sort(i,4)));
        %         T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
            
            IdxImaginary = ~imag(Etheoka2_tmp);
            
            T.Etheoka1 = Etheoka1_tmp(IdxImaginary);
            T.Etheoka2 = Etheoka2_tmp(IdxImaginary);
            T.Peaks = [T.hkl_sort(IdxImaginary,:) T.Etheoka1 T.Etheoka2];

%             for k = 1:length(Etheoka1_tmp)
%                 Etheoka1_tmp1(k,1) = isreal(Etheoka1_tmp(k));
%             end
%             
%             Etheoka1_tmp2 = Etheoka1_tmp.*Etheoka1_tmp1;
%             Etheoka2_tmp2 = Etheoka1_tmp.*Etheoka1_tmp1;
% 
%             Etheoka1_tmp2 = Etheoka1_tmp.*Etheoka1_tmp1;
%             Etheoka1_tmp2(Etheoka1_tmp2==0) = []
%             T.Etheoka1 = Etheoka1_tmp2;
%     
%             for k = 1:length(Etheoka2_tmp)
%                 Etheoka2_tmp1(k,1) = isreal(Etheoka2_tmp(k));
%             end
%             Etheoka2_tmp2 = Etheoka2_tmp.*Etheoka2_tmp1;
%             Etheoka2_tmp2(Etheoka2_tmp2==0) = []
%             T.Etheoka2 = Etheoka2_tmp2;
    
    
%             T.Peaks = [T.hkl_sort(Etheoka1_tmp1,:) T.Etheoka1 T.Etheoka2];
            assignin('base','TPeaks',T.Peaks)
        % Calculation of peak positions for bcc materials
        elseif strcmp(T.cs,'fcc')
            % Calculation of all possible hkl combinations
            [T.h, T.k, T.l] = ndgrid(1:10, 0:9, 0:9);
            T.d = T.h+T.k+T.l;
            i = find(rem(T.d,2) == 0);
            j = find(rem(T.d,2) == 1);
            T.p = [T.h(i),T.k(i),T.l(i);T.h(j),T.k(j),T.l(j)];
            % Use only hkl with hkl² < hkl²max
            for i=1:size(T.p,1)
                if (T.p(i,1)^2 + T.p(i,2)^2 + T.p(i,3)^2) <= T.hklquadratmax
                    T.y(i,:) = T.p(i,:);
                end
            end
            % delete zero rows
            T.y(all(T.y == 0,2),:)=[];
            % Use only hkl that are allowed for fcc materials
            for i=1:size(T.y,1)
                if T.y(i,1) >= T.y(i,2) && T.y(i,1) >= T.y(i,3) && T.y(i,2) >= T.y(i,3)
                    T.z(i,:) = T.y(i,:);
                end
            end
            % delete zero rows
            T.z(all(T.z == 0,2),:)=[];
            % Find only hkl that are all even
            for i=1:size(T.z,1)
                if rem(T.z(i,1),2) == 0 && rem(T.z(i,2),2) == 0 && rem(T.z(i,3),2) == 0
                    T.w1(i,:) = T.z(i,:);
                end
            end
            % delete zero rows
            T.w1(all(T.w1 == 0,2),:)=[];
            % Find only hkl that are all odd
            for i=1:size(T.z,1)
                if rem(T.z(i,1),2) == 1 && rem(T.z(i,2),2) == 1 && rem(T.z(i,3),2) == 1
                    T.w2(i,:) = T.z(i,:);
                end
            end
            % delete zero rows
            T.w2(all(T.w2 == 0,2),:)=[];
        
            T.w = [T.w1; T.w2];
            % delete zero rows
            T.w(all(T.w == 0,2),:)=[];
            % Calculation of theoretical d spacings for the used hkl values
            for i = 1:size(T.w,1)
                T.dtheo(i,:) = T.a0/(sqrt(T.w(i,1)^2+T.w(i,2)^2+T.w(i,3)^2));
            end
        
            T.hkl = [T.w, T.dtheo];
            % Sort columns in descending order
            T.hkl_sort = sortrows(T.hkl, -4);
            [C,ia,ic] = unique(T.hkl_sort(:,4),'rows','last');
            T.hkl_sort = T.hkl_sort(ia,1:4);
            T.hkl_sort = sortrows(T.hkl_sort, -4);
    %         % Calculation of theoreitcal energy positons for the used hkl values
    %         for i = 1:size(T.hkl_sort,1)
    %             T.Etheo(i,:) = 2.*asind(T.lambdaka1./(20.*T.hkl_sort(i,4)));
    %             T.Etheoka2 = 2.*asind(T.lambdaka2./(20.*T.hkl_sort(i,4)));
    %     %         T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
    %         end
            
            % Calculation of theoreitcal energy positons for the used hkl values
            for i = 1:size(T.hkl_sort,1)
                Etheoka1_tmp(i,:) = 2.*asind(T.lambdaka1./(20.*T.hkl_sort(i,4)));
                Etheoka2_tmp(i,:) = 2.*asind(T.lambdaka2./(20.*T.hkl_sort(i,4)));
        %         T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
            
            IdxImaginary = ~imag(Etheoka2_tmp);
            
            T.Etheoka1 = Etheoka1_tmp(IdxImaginary);
            T.Etheoka2 = Etheoka2_tmp(IdxImaginary);
            T.Peaks = [T.hkl_sort(IdxImaginary,:) T.Etheoka1 T.Etheoka2];

%             for k = 1:length(Etheoka1_tmp)
%                 Etheoka1_tmp1(k,1) = isreal(Etheoka1_tmp(k));
%             end
%             Etheoka1_tmp2 = Etheoka1_tmp.*Etheoka1_tmp1;
%             Etheoka1_tmp2(Etheoka1_tmp2==0) = [];
%             T.Etheoka1 = Etheoka1_tmp2;
%     
%             for k = 1:length(Etheoka2_tmp)
%                 Etheoka2_tmp1(k,1) = isreal(Etheoka2_tmp(k));
%             end
%             Etheoka2_tmp2 = Etheoka2_tmp.*Etheoka2_tmp1;
%             Etheoka2_tmp2(Etheoka2_tmp2==0) = [];
%             T.Etheoka2 = Etheoka2_tmp2;
%     
%     
%             T.Peaks = [T.hkl_sort(Etheoka1_tmp1,:) T.Etheoka1 T.Etheoka2];
    
        %--------------------------------------------------------------------------
        else
            T.hkl = T.Material.HKLdspacing;
            [C,ia,ic] = unique(T.hkl(:,4),'rows','last');
            T.hkl = T.hkl(ia,1:4);
            T.hkl_sort = sortrows(T.hkl, -4);
    %         for i = 1:size(T.hkl_sort,1)
    %             T.Etheo(i,:) = 2.*asind(T.lambdaka1./(20.*T.hkl_sort(i,4)));
    %             T.Etheoka2 = 2.*asind(T.lambdaka2./(20.*T.hkl_sort(i,4)));
    %     %         T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
    %         end
    
            for i = 1:size(T.hkl_sort,1)
                Etheoka1_tmp(i,:) = 2.*asind(T.lambdaka1./(20.*T.hkl_sort(i,4)));
                Etheoka2_tmp(i,:) = 2.*asind(T.lambdaka2./(20.*T.hkl_sort(i,4)));
        %         T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
            
            IdxImaginary = ~imag(Etheoka2_tmp);
            
            T.Etheoka1 = Etheoka1_tmp(IdxImaginary);
            T.Etheoka2 = Etheoka2_tmp(IdxImaginary);
            T.Peaks = [T.hkl_sort(IdxImaginary,:) T.Etheoka1 T.Etheoka2];

%             for k = 1:length(Etheoka1_tmp)
%                 Etheoka1_tmp1(k,1) = isreal(Etheoka1_tmp(k));
%             end
%             Etheoka1_tmp2 = Etheoka1_tmp.*Etheoka1_tmp1;
%             Etheoka1_tmp2(Etheoka1_tmp2==0) = [];
%             T.Etheoka1 = Etheoka1_tmp2;
%     
%             for k = 1:length(Etheoka2_tmp)
%                 Etheoka2_tmp1(k,1) = isreal(Etheoka2_tmp(k));
%             end
%             Etheoka2_tmp2 = Etheoka2_tmp.*Etheoka2_tmp1;
%             Etheoka2_tmp2(Etheoka2_tmp2==0) = [];
%             T.Etheoka2 = Etheoka2_tmp2;
%     
%             assignin('base','TEtheoka1',T.Etheoka1)
%             assignin('base','TEtheoka2',T.Etheoka2)
%             assignin('base','Thkl_sort',T.hkl_sort)
%             T.Peaks = [T.hkl_sort(Etheoka1_tmp1,:) T.Etheoka1 T.Etheoka2];
            
        end
    %     assignin('base','TPeaks',T)
        % Create matrix for the line plot of the peak positions (X values)
        for i = 1:size(T.Peaks,1)
            T.X1(i,:) = [T.Peaks(i,5) T.Peaks(i,5) nan];
            T.X1ka2(i,:) = [T.Peaks(i,6) T.Peaks(i,6) nan];
        end
        % Adjust the size of matrix to the measurement
        T.X2 = reshape(T.X1',size(T.Peaks,1).*3,1);
        T.X2(size(T.Peaks,1).*3,:) = [];
        T.X3 = repmat(T.X2,1,length(T.Material));
        % kalpha2
        T.X2ka2 = reshape(T.X1ka2',size(T.Peaks,1).*3,1);
        T.X2ka2(size(T.Peaks,1).*3,:) = [];
        T.X3ka2 = repmat(T.X2ka2,1,length(T.Material));
        % Adjust the size of matrix to the measurement
        T.Y2 = reshape(T.Y1',3,length(T.Material));
        T.Y3 = repmat(T.Y2,size(T.Peaks,1),1);
        T.Y3(size(T.Peaks,1).*3,:)= [];
        
        Peakhandles{k} = T;
        end
        % Show results in command window
%         fprintf(['\n2\theta positions of ',MPDFileName,' ,\n\n'])
%         fprintf('%3s   %9s   %5s\n','hkl','d-spacing','E-Pos');
%         fprintf('%d%d%d   %.4f      %.4f\n', [T.Peaks].')
    else
        P.ElementalFormula = ElementalFormula;
        P.MPDFileName = MPDFileName;
        P.ShowSubstratePeaks = 0;
        
        [Sample, T] = CreateSampleEPostheo(P);
        
        % TwoTheta of measurement
        T.twotheta = twotheta;
        
        % Info from material
        % Maximum Energy up to which peak positions are calculated
        T.EMax = Emax;
        % Crystal structure of the material
        T.cs = T.Material.CrystalStructure;
        % Lattice parameter of the material
        T.a0 = T.Material.LatticeParameter;
        % Calculation of minimum d spacing
        T.dmin = (0.6199/sind(T.twotheta/2))/T.EMax;
        % Calculation of maximum hkl²
        if ~isempty(T.a0)
            T.hklquadratmax = (T.a0(1)/T.dmin)^2;
        else
            T.hklquadratmax = [];
        end
        
        % Calculation of the maximum peak intensities of the respecive spectrum
        % Intensity maximum
        T.Peaks_y = 100;
        % Create matrix for the line plot of the peak positions (Y values)
        T.Y1 = [0 T.Peaks_y nan];
        
        %% Plot diffraction lines from Material
        % Calculation of peak positions for bcc materials
        if strcmp(T.cs,'bcc')
            % Calculation of all possible hkl combinations
            [T.h, T.k, T.l] = ndgrid(1:10, 0:9, 0:9);
            T.d = T.h+T.k+T.l;
            i = find(rem(T.d,2) == 0);
            T.p = [T.h(i),T.k(i),T.l(i)];
            % Use only hkl with hkl² < hkl²max
            for i=1:size(T.p,1)
                if (T.p(i,1)^2 + T.p(i,2)^2 + T.p(i,3)^2) <= T.hklquadratmax
                    T.y(i,:) = T.p(i,:);
                end
            end
            % delete zero rows
            T.y(all(T.y == 0,2),:)=[];
        %     assignin('base','y',T.y)
            % Use only hkl that are allowed for bcc materials
            for i=1:size(T.y,1)
                if T.y(i,1) >= T.y(i,2) && T.y(i,1) >= T.y(i,3) && T.y(i,2) >= T.y(i,3)
                   T.z(i,:) = T.y(i,:);
                end
            end
            % delete zero rows
            T.z(all(T.z == 0,2),:)=[];
            % Calculation of theoretical d spacings for the used hkl values
            for i = 1:size(T.z,1)
                T.dtheo(i,:) = T.a0/(sqrt(T.z(i,1)^2+T.z(i,2)^2+T.z(i,3)^2));
            end
        
            T.hkl = [T.z T.dtheo];
            % Sort columns in descending order
            T.hkl_sort = sortrows(T.hkl, -4);
            [C,ia,ic] = unique(T.hkl_sort(:,4),'rows','last');
            T.hkl_sort = T.hkl_sort(ia,1:4);
            T.hkl_sort = sortrows(T.hkl_sort, -4);
            % Calculation of theoreitcal energy positons for the used hkl values
            for i = 1:size(T.hkl_sort,1)
                T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
            
            T.Peaks = [T.hkl_sort T.Etheo];
        
        % Calculation of peak positions for bcc materials
        elseif strcmp(T.cs,'fcc')
            % Calculation of all possible hkl combinations
            [T.h, T.k, T.l] = ndgrid(1:10, 0:9, 0:9);
            T.d = T.h+T.k+T.l;
            i = find(rem(T.d,2) == 0);
            j = find(rem(T.d,2) == 1);
            T.p = [T.h(i),T.k(i),T.l(i);T.h(j),T.k(j),T.l(j)];
            % Use only hkl with hkl² < hkl²max
            for i=1:size(T.p,1)
                if (T.p(i,1)^2 + T.p(i,2)^2 + T.p(i,3)^2) <= T.hklquadratmax
                    T.y(i,:) = T.p(i,:);
                end
            end
            % delete zero rows
            T.y(all(T.y == 0,2),:)=[];
            % Use only hkl that are allowed for fcc materials
            for i=1:size(T.y,1)
                if T.y(i,1) >= T.y(i,2) && T.y(i,1) >= T.y(i,3) && T.y(i,2) >= T.y(i,3)
                    T.z(i,:) = T.y(i,:);
                end
            end
            % delete zero rows
            T.z(all(T.z == 0,2),:)=[];
            % Find only hkl that are all even
            for i=1:size(T.z,1)
                if rem(T.z(i,1),2) == 0 && rem(T.z(i,2),2) == 0 && rem(T.z(i,3),2) == 0
                    T.w1(i,:) = T.z(i,:);
                end
            end
            % delete zero rows
            T.w1(all(T.w1 == 0,2),:)=[];
            % Find only hkl that are all odd
            for i=1:size(T.z,1)
                if rem(T.z(i,1),2) == 1 && rem(T.z(i,2),2) == 1 && rem(T.z(i,3),2) == 1
                    T.w2(i,:) = T.z(i,:);
                end
            end
            % delete zero rows
            T.w2(all(T.w2 == 0,2),:)=[];
        
            T.w = [T.w1; T.w2];
            % delete zero rows
            T.w(all(T.w == 0,2),:)=[];
            % Calculation of theoretical d spacings for the used hkl values
            for i = 1:size(T.w,1)
                T.dtheo(i,:) = T.a0/(sqrt(T.w(i,1)^2+T.w(i,2)^2+T.w(i,3)^2));
            end
        
            T.hkl = [T.w, T.dtheo];
            % Sort columns in descending order
            T.hkl_sort = sortrows(T.hkl, -4);
            [C,ia,ic] = unique(T.hkl_sort(:,4),'rows','last');
            T.hkl_sort = T.hkl_sort(ia,1:4);
            T.hkl_sort = sortrows(T.hkl_sort, -4);
            % Calculation of theoreitcal energy positons for the used hkl values
            for i = 1:size(T.hkl_sort,1)
                T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
        
            T.Peaks = [T.hkl_sort T.Etheo];
        %--------------------------------------------------------------------------
        else
            T.hkl = T.Material.HKLdspacing;
            [C,ia,ic] = unique(T.hkl(:,4),'rows','last');
            T.hkl = T.hkl(ia,1:4);
            T.hkl_sort = sortrows(T.hkl, -4);
            for i = 1:size(T.hkl,1)
                T.Etheo(i,:) = (0.6199/sind(T.twotheta/2))/T.hkl_sort(i,4);
            end
            a = T.Etheo < T.EMax;
            T.Peaks = [T.hkl_sort(1:length(a(a==1)),:) T.Etheo(a)];
        end
        
        % Calculate tau
        T.absorbcoeff = Sample.Materials.LAC(T.Etheo);
        % Calculate tau for Emax values
        T.tau = (sind(T.twotheta./2).*cosd(0))./(2.*T.absorbcoeff./10000);
        assignin('base','T',T)
        T.Peaks(:,6) = T.tau;
        
        for i = 1:size(T.Peaks,1)
            T.X1(i,:) = [T.Peaks(i,5) T.Peaks(i,5) nan];
        end
        T.X2 = reshape(T.X1',size(T.Peaks,1).*3,1);
        T.X2(size(T.Peaks,1).*3,:) = [];
        T.X3 = repmat(T.X2,1,1);
        % Adjust the size of matrix to the measurement
        T.Y2 = reshape(T.Y1',3,1);
        T.Y3 = repmat(T.Y2,size(T.Peaks,1),1);
        T.Y3(size(T.Peaks,1).*3,:)= [];
        
        Peakhandles = T;
        % Show results in command window
        fprintf(['\nEnergy positions of ',MPDFileName,' for 2theta = ',num2str(twotheta),'°','\n\n'])
        fprintf('%3s   %9s   %5s\n','hkl','d-spacing','E-Pos');
        fprintf('%d%d%d   %.4f      %.4f\n', [T.Peaks(:,1:5)].')
    end
end