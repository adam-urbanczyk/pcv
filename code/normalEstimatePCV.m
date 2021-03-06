function [pts, normVectors ] = normalEstimatePCV( filepath,  neiSize)
originalPath = cd;
path = which('normalEstimatePCV');
cd(path(1:end - length('normalEstimatePCV.m') ));

addpath ('toolbox/jjcao_io')
addpath ('toolbox/jjcao_point')
addpath ('toolbox/jjcao_common')
addpath ('toolbox/jjcao_interact')
addpath ('toolbox/jjcao_plot')

addpath('toolbox/zj_fitting')
addpath('toolbox/zj_deviation')

addpath('toolbox/cvx')
cvx_setup
%% debug options
ADDNOISE = 0;
ADDOUTLIER = 0 ;
TP.debug_data = 0;
TP.debug_taproot = 0 ;

%% algorithm options
TP.k_knn_feature = ceil(neiSize/2);
TP.k_knn_normals = ceil(neiSize/4); 
TP.k_knn  = ceil(neiSize);

TP.sigma_threshold = 0.05;
TP.ran_num_min = 150 ; TP.ran_num_max = 250 ;
TP.density_num = 10 ; 
%% read input && add noise && plot it && build kdtree
[P.pts ] = read_off(filepath);
pts = P.pts; 
nSample = size(P.pts,1);

alpha = 4 ;
beta = 2 ;
% add noise & outliers
if ADDNOISE
    type = 'gaussian';%type = 'random';% type = 'gaussian';% type = 'salt & pepper';
    base = 'average_edge';%base = 'average_edge'% base = 'diagonal_line';
    p3 = 0.3;
    kdtree = kdtree_build(P.pts);
    P.pts = pcd_noise_point(P.pts, type, base, p3,kdtree);
    kdtree_delete(kdtree);
end

% build kdtree
P.kdtree = kdtree_build(P.pts);
%% show the density
[l density] = compute_average_radius(P.pts ,TP.density_num ,P.kdtree) ;

%% compute initial features (a ribbon)
[sigms , normVectors , errs , normals_comW] = compute_points_sigms_normals_two(P.pts, TP.k_knn_feature, P.kdtree, TP.k_knn_normals);

TP.feature_threshold = feature_threshold_selection(sigms,TP);

P.init_feat = find(sigms > TP.feature_threshold);
feature_sigms = sigms(P.init_feat);
[~, id_sigms] = sort(feature_sigms);
TP.id_feature = P.init_feat(id_sigms);

if TP.debug_data;
    figure('Name','Input'); set(gcf,'color','white');set(gcf,'Renderer','OpenGL');
    movegui('northeast');
    non_feature = setdiff(1:nSample , TP.id_feature);
    scatter3(P.pts(non_feature,1),P.pts(non_feature,2),P.pts(non_feature,3),30,'.','MarkerEdgeColor',GS.CLASS_COLOR5);  hold on;
    scatter3(P.pts(TP.id_feature,1),P.pts(TP.id_feature,2),P.pts(TP.id_feature,3),30,'.','MarkerEdgeColor',GS.CLASS_COLOR5);  hold on;
    axis off;axis equal;
    view3d rot; % vidw3d zoom; % r for rot; z for zoom;
end

nFeature = length(TP.id_feature)

%% compute nomals
density_r = zeros(1 , nFeature) ;

for i = 1:nFeature
    ii = TP.id_feature(i);
     
    knn_big = kdtree_k_nearest_neighbors(P.kdtree,P.pts(ii,:),ceil(neiSize*1.7))';
    knn = knn_big(1:TP.k_knn);
    
    plane_knn = setdiff(knn_big , TP.id_feature) ;
    inner_threshold = beta * mean(errs(plane_knn)) ;
    
    points = P.pts(knn , :) ;
    temp_nor = normals_comW(knn , :) ;
    local_density = density(knn) ;
    
    temp_W = abs(temp_nor * temp_nor');
    local_W = exp((temp_W.^alpha)./(0.85.^alpha));
    
    s_v = sort(local_density) ;
    density_r(i) = mean(s_v(TP.k_knn - 14:TP.k_knn))/mean(s_v(1:15)) ;
    local_density = (local_density.^2) ;
    density_w = local_density' * local_density;
    local_W = density_w .* local_W;
 
    if density_r(i) > 2
        ran_num = TP.ran_num_max ;
    else
        ran_num = TP.ran_num_min ;
    end
    [normVectors(ii,:)] = compute_normal_NWR_EACH2(points , local_W , ran_num , inner_threshold) ;
end
%%
kdtree_delete(P.kdtree);

cd(originalPath);
end

