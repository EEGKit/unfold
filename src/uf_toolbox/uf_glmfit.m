function [EEG,beta] = uf_glmfit(EEG,varargin)
%% Fit the fullX designmatrix on the data and returns beta and stats
% This function solves the Equation X*beta = EEG.data, with X = Designmat.
% There are multiple algorithms implemented, a slow iterative algorithm
% that runs on sparse matrices (default) that solves each channel in turn
% and the matlab algorithm which solves all channels at the same time, but
% take quite a lot of memory.
%
%Arguments:
%   cfg.method (string):
%    * "lsmr"      default; an iterative solver is used, this is
%    very memory efficient, but is a lot slower than the 'time' option
%    because each electrode has to be solved independently. The LSMR
%    algorithm is used for sparse iterative solving.
%
%    * "par-lsmr"  same as lsmr, but uses parfor with ncpu-1. This does not
%    seem to be any faster at the moment (unsure why). Not recommended
%
%    * "matlab"    , uses matlabs native A/b solver. For moderate to big
%    design-matrices it will need *a lot* of memory (40-60GB is easily
%    reached)
%
%    * "pinv"      A naive pseudo-inverse, generally not recommended due to
%    floating point instability
%
%    * "glmnet"    uses glmnet to fit the linear system. This by default uses
%    L1-Norm aka lasso (specified as cfg.glmnetalpha = 1). For
%    ridge-regression (L2-Norm) use (cfg.glmnetalpha = 0). Something
%    inbetween results in elastic-net. We use the cvglmnet functionality
%    that automatically does crossvalidation to estimate the lambda
%    parameter (i.e. how strongly parameter values should be regularised
%    compared to the fit of the model). We use the glmnet recommended
%    'lambda_1se', i.e. minimum lambda + 1SE buffer towards more strict
%    regularisation.
%   
%
%   cfg.lsmriterations: (default 400), defines how many steps the iterative
%      solver should search for a solution. While the solver is mostly monotonic (see paper), it is recommended
%      to increase the iterations. A limit is only defined because in our experience, high number of iterations
%      are a result of strong collinearities, and hint to a faulty model
%
%   cfg.glmnetalpha: (default 1, as in glmnet), can be 0 for L2 norm, 1 for L1-norm or
%                    something inbetween for elastic net
%   cfg.fold_event: (defaultempty), (development / no unit-test) defines EEG.events on which the
%                    crossvalidation folds for glmnet should be placed
%
%   cfg.channel(array): Restrict the beta-calculation to a subset of
%               channels. Default is all channels
%
%   cfg.debug (boolean): 0, only with method:matlab, outputs additional
%                  details from the solver used
%
%   cfg.precondition (boolean): 1, scales each row of Xdc to SD=1. This
%               increase the solving speed by factor ~2. For very large
%               matrices you might run into memory problems. Deactivate
%               then.
%
%   cfg.ica (boolean):0, use data or ICA components (have to be in
%               EEG.icaact). cfg.channel chooses the components.
%
%   EEG:  the EEG set, need to have EEG.unfold.Xdc compatible with
%         the size of EEG.data
%
%Return:
% EEG.unfold.beta: array (nchan x ntime x npred) (ntime could be
% n-timesplines, n-fourierbasis or samples)
%
%*Example:*
% EEG = dc_glmfit(EEG);
% EEG = dc_glmfit(EEG,'method','matlab','channel',[3 5]);
%

fprintf('\nuf_glmfit(): Fitting deconvolution model...');


cfg = finputcheck(varargin,...
    {'method', 'string',{'par-lsmr','lsmr','matlab','pinv','glmnet'}, 'lsmr';
    'lsmriterations','integer',[],400;
    'glmnetalpha','real',[],1;... # used for glmnet
    'fold_event','',[],[];...
    'precondition','boolean',[],1;... % inofficial
    'channel','integer',[],1:size(EEG.data,1);
    'ica','boolean',[],0;
    'debug','boolean',[],0;
    },'mode','ignore');
if(ischar(cfg)); error(cfg);end



if cfg.ica
    assert(ndims(EEG.icaact) ==2,'EEG.icaact needs to be unconcatenated. Did you epoch your data already? We need continuous data for this fit')
else
    assert(ndims(EEG.data) ==2,'EEG.data needs to be unconcatenated. Did you epoch your data already? We need continuous data for this fit')
end
assert(size(EEG.unfold.Xdc,1) == size(EEG.data,2),'Size of designmatrix (%d,%d), not compatible with EEG data(%d,%d)',size(EEG.unfold.Xdc),size(EEG.data))
if any(isnan(EEG.unfold.Xdc(:)))
    warning('NAN values found in Xdc designmatrix.  Maybe you need uf_imputeMissing?')
end

X = EEG.unfold.Xdc;

disp('solving the equation system');
t = tic;

if cfg.ica
    data = EEG.icaact;
else
    data = EEG.data;
end

assert(any(~isnan(data(:))),'Error: We found a NaN in your specified timeseries-data')
%% Remove data that is unnecessary for the fit
% this helps calculating better tolerances for lsmr
emptyRows = sum(abs(X),2) == 0;
X(emptyRows,:)  = [];
data(:,emptyRows) = [];

if cfg.precondition
    normfactor = sqrt(sum(X.^2)); % cant use norm because of sparsematrix
    % X = X./normfactor; %matlab 2016b and later
    X = bsxfun(@rdivide,X,normfactor);
end
%% Main methods
beta = nan(size(X,2),EEG.nbchan);
if  strcmp(cfg.method,'matlab') % save time
    if cfg.debug
        spparms('spumoni',2)
    end
    beta= X \(double(data'));
    
    
    
elseif strcmp(cfg.method,'pinv')
    Xinv = pinv(full(X));
    
    for e = cfg.channel
        beta(:,e)= (Xinv*squeeze(data(e,:,:))');
    end
    
elseif strcmp(cfg.method,'lsqr')
    for e = cfg.channel
        beta(:,e) = lsqr(X,data(e,:)',10^-8,cfg.lsmriterations);
    end
    
elseif strcmp(cfg.method,'lsmr')
    
    
    for e = cfg.channel
        t = tic;
        fprintf('\nsolving electrode %d (of %d electrodes in total)',e,length(cfg.channel))
        
        % use iterative solver for least-squares problems (lsmr)
        [beta(:,e),ISTOP,ITN] = lsmr(X,double(data(e,:)'),[],10^-8,10^-8,[],cfg.lsmriterations); % ISTOP = reason why algorithm has terminated, ITN = iterations

        if ISTOP == 7
            warning(['The iterative least squares did not converge for channel ',num2str(e), ' after ' num2str(ITN) ' iterations. You can either try to increase the number of iterations using the option ''lsmriterations'' or it might be, that your model is highly collinear and difficult to estimate. Check the designmatrix EEG.unfold.X for collinearity.'])
        elseif ITN == cfg.lsmriterations
            warning(['The iterative least squares (likely) did not converge for channel ',num2str(e), ' after ' num2str(ITN) ' iterations. You can either try to increase the number of iterations using the option ''lsmriterations'' or it might be, that your model is highly collinear and difficult to estimate. Check the designmatrix EEG.unfold.X for collinearity.'])
        end
        fprintf('... %i iterations, took %.1fs',ITN,toc(t))
        %beta(:,e) =
        %lsqr(EEG.unfold.Xdc,sparse(double(EEG.data(e,:)')),[],30);
        
    end
    
elseif strcmp(cfg.method,'par-lsmr')
    fprintf('starting parpool with ncpus...')
    pools = gcp('nocreate');
    cpus = feature('numCores');
    if size(pools) == 0
        pool = parpool(cpus);
    end
    fprintf('done\n')
    addpath('../lib/lsmr/')
    beta = nan(size(X,2),EEG.nbchan);
    Xdc = X;
    data = double(data');
    % go tru channels
    fprintf('starting parallel loop')
    parXdc = parallel.pool.Constant(Xdc);
    parData= parallel.pool.Constant(data);
    parfor e = cfg.channel
        t = tic;
        
        fprintf('\nsolving electrode %d (of %d electrodes in total)',e,length(cfg.channel))
        % use iterative solver for least-squares problems (lsmr)
        [beta(:,e),ISTOP,ITN] = lsmr(parXdc.Value,parData.Value(:,e),[],10^-8,10^-8,[],cfg.lsmriterations); % ISTOP = reason why algorithm has terminated, ITN = iterations
        if ISTOP == 7
            warning(['The iterative least squares did not converge for channel ',num2str(e), ' after ' num2str(ITN) ' iterations. You can either try to increase the number of iterations using the option ''lsmriterations'' or it might be, that your model is highly collinear and difficult to estimate. Check the designmatrix EEG.unfold.X for collinearity.'])
        elseif ITN == cfg.lsmriterations
            warning(['The iterative least squares (likely) did not converge for channel ',num2str(e), ' after ' num2str(ITN) ' iterations. You can either try to increase the number of iterations using the option ''lsmriterations'' or it might be, that your model is highly collinear and difficult to estimate. Check the designmatrix EEG.unfold.X for collinearity.'])
        end
        fprintf('... took %i iterations and %.1fs',ITN,toc(t))
        
        %beta(:,e) =
        %lsqr(EEG.unfold.Xdc,sparse(double(EEG.data(e,:)')),[],30);
        
    end
    
    
elseif strcmp(cfg.method,'matlab') % save time
    
    
    if cfg.debug
        spparms('spumoni',2)
    end
    
    beta(:,cfg.channel) = X \ sparse(double(data(cfg.channel,:)'));
    
elseif strcmp(cfg.method,'pinv')
    Xinv = pinv(full(X));
    beta = calc_beta(data,EEG.nbchan,Xinv,cfg.channel);
    
    
elseif strcmp(cfg.method,'glmnet')
    beta = nan(size(X,2)+1,EEG.nbchan); %plus one, because glmnet adds a intercept
    for e = cfg.channel
        t = tic;
        fprintf('\nsolving electrode %d (of %d electrodes in total)',e,length(cfg.channel))
        %glmnet needs double precision
        if isempty(cfg.fold_event)
            fit = cvglmnet(X,(double(data(e,:)')),'gaussian',struct('alpha',cfg.glmnetalpha));
        else
            [train,test]=uf_cv_getFolds(EEG,'fold_event',cfg.fold_event);
            foldid = nan(1,size(EEG.data,2));
            for f = 1:length(test)
                foldid(test(f).ix) = f;
            end
            foldid(emptyRows) = [];
            fit = cvglmnet(X,(double(data(e,:)')),'gaussian',struct('alpha',cfg.glmnetalpha),[],[],foldid);
        end
        
        %find best cv-lambda coefficients
        beta(:,e) = cvglmnetCoef(fit,'lambda_1se')';
        fit.glmnet_fit = [];
        EEG.unfold.glmnet(e) = fit;
        fprintf('... took %.1fs',toc(t))
        
    end
    beta = beta([2:end 1],:); %put the dc-intercept last
    if cfg.precondition
        normfactor = [normfactor 1];
    end
    EEG = uf_designmat_addcol(EEG,ones(1,size(EEG.unfold.Xdc,1)),'glmnet-DC-Correction');
    
    
    
end
fprintf('\n LMfit finished \n')

if cfg.precondition
    % rescaling to remove preconditioning
    beta = bsxfun(@rdivide,beta,full(normfactor)');
end
beta = beta'; % I prefer channels X betas (easier to multiply things to)


% We need to remove customrows, as they were not timeexpanded.
% eventcell = cellfun(@(x)iscell(x(1)),EEG.unfold.eventtypes)*1;

eventnan = find(cellfun(@(x)isnan(x(1)),EEG.unfold.variabletypes));


betatmp = beta(:,1:(end-length(eventnan)));
if ~isempty(betatmp)
    % beta right now:
    % channel x Xdc-columns = channel x (times * n-predictors)
    %
    % beta should be:
    % channel x times x n-predictor
    %
    nchannel = size(beta,1);
    betaOut = reshape(betatmp,nchannel,size(EEG.unfold.timebasis,1),sum(~ismember(EEG.unfold.cols2variablenames,eventnan)));
    EEG.unfold.beta_dc = betaOut;
else
    % in special cases we might not have a proper beta but only covariates betas
    EEG.unfold.beta_dc = [];
end

if length(eventnan)>0
    %     EEG.betaCustomrow = beta(end+1-length(eventnan):end);
    customBeta = beta(:,(end+1-length(eventnan)):end);
%     customBeta = reshape(customBeta,size(customBeta,1),[]);
    EEG.unfold.beta_dcCustomrow = customBeta;
end
EEG.unfold.channel = cfg.channel;

end

function [beta] = calc_beta(data,nbchan,Xinv,channel)
beta = nan(size(Xinv,1),nbchan);
for c = channel
    beta(:,c)= (Xinv*squeeze(data(c,:,:))');
end
end
