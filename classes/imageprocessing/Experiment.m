%% Experiment: class containing multiple image stacks stored as separate Genotype objects
% Class description

classdef Experiment < handle
    properties (Access = public)
        %% Experiment properties
        ExperimentName
        ExperimentPath
        Genotypes
        NumberOfGenotypes
        CurvesTraced
    end
    
    properties (Access = private)
        %% Private data properties
        ExperimentDate  = tdate('l')
        HYPOCOTYLLENGTH = 250 % Distance to set cutoff for hypocotyl
    end
    
    methods (Access = public)
        %% Constructor and main methods
        function obj = Experiment(varargin)
            %% Constructor method for Experiment
            if ~isempty(varargin)
                % Parse inputs to set properties
                vargs = varargin;
            else
                % Set default properties for empty object
                vargs = {};
            end
            
            prps   = properties(class(obj));
            deflts = { ...
                'ExperimentPath'   , pwd   ; ...
                'NumberOfGenotypes', 0   } ;
            obj    = classInputParser(obj, prps, deflts, vargs);
            
            [obj.ExperimentName, ~] = getDirName(obj.ExperimentPath);
            
        end
        
        %         function obj = AddGenotypes(varargin)
        function AddGenotypes(obj, ext)
            %% Add Genotype to Experiment
            if nargin < 2
                ext = '.TIF';
            end
            
            % Get all directories (exclude . and ..)
            fld   = dir(obj.ExperimentPath);
            fld   = fld(3:end);
            fldrs = fld(cat(1, fld.isdir));
            
            %% Create Genotype child objects
            if isempty(obj.Genotypes)
                obj.Genotypes = Genotype;
            end
            
            try
                G = arrayfun(@(f) initializeGenotype(f.name, 'Parent', obj, ...
                    'image_extension', ext), fldrs, 'UniformOutput', 0);
                G = cat(1, G{:});
                
                obj.Genotypes = G;
                obj.NumberOfGenotypes = numel(G);
            catch
                fprintf(2, '\nError adding Genotype %d\n', ...
                    obj.NumberOfGenotypes);
            end
            
        end
        
        function sdls = FindSeedlingAllGenotypes(obj, v, par)
            %% Extract Seedling from every frame of each Genotype
            if nargin < 3
                par = 0;
            end
            
            try
                if v
                    t = tic;
                    fprintf('Extracting Seedlings from Experiment %s\n', ...
                        obj.ExperimentName);
                end
                
                % Find and Sort Seedlings
                gens   = arrayfun(@(g) g, obj.Genotypes, 'UniformOutput', 0);
                hypLen = obj.HYPOCOTYLLENGTH;
                
                % Set RawSeedlings to empty cell array
                frms = cellfun(@(g) (1 : g.TotalImages)', ...
                    gens, 'UniformOutput', 0);
                rs   = cellfun(@(g,f) cell(numel(f), 1), ...
                    gens, frms, 'UniformOutput', 0);
                cellfun(@(g,f,r) g.setRawSeedlings(f,1,r), ...
                    gens, frms, rs, 'UniformOutput', 0);
                
                if par
                    %% Run with parallelization [NOT TESTED]
                    sdls = cell(numel(gens), 1);
                    parfor g = 1 : numel(gens)
                        gen     = gens{g};
                        sdls{g} = gen.FindSeedlings( ...
                            1 : gen.TotalImages, hypLen, v);
                    end
                    
                    % For some reason parallelization can't set properties
                    nsdls = cellfun(@(s) (1 : size(s,2))', ...
                        sdls, 'UniformOutput', 0);
                    cellfun(@(g,f,s,r) g.setRawSeedlings(f,s,r), ...
                        gens, frms, nsdls, sdls, 'UniformOutput', 0);
                    
                else
                    %% Run on single-thread
                    sdls = cellfun(@(g) g.FindSeedlings( ...
                        1:g.TotalImages, hypLen, v), gens, 'UniformOutput', 0);
                end
                
                % Filter and Sort
                cellfun(@(x) x.SortSeedlings(v), gens, 'UniformOutput', 0);
                
                if v
                    fprintf('[%.02f sec] Extracted Seedlings from %s\n', ...
                        toc(t), obj.ExperimentName);
                end
                
            catch e
                %% Error
                fprintf(2, 'Error extracting Seedlings from %s\n%s', ...
                    obj.ExperimentName, e.getReport);
                sdls = [];
                
                if v
                    fprintf(2, '[%.02f sec]\n', toc(t));
                end
            end
            
        end
        
        function hyps = FindHypocotylAllGenotypes(obj, v)
            %% Extract Hypocotyl from every frame of each Seedling from
            % all Genotypes from this Experiment object
            try
                
                if v
                    fprintf('Extracting Hypocotyls from %s\n', ...
                        obj.ExperimentName);
                    t = tic;
                end
                
                gens = obj.Genotypes;
                hyps = arrayfun(@(x) x.FindHypocotylAllSeedlings(v), ...
                    gens, 'UniformOutput', 0);
                
                if v
                    fprintf('[%.02f sec] Extracting Hypocotyls from %s\n', ...
                        toc(t), obj.ExperimentName);
                end
                
            catch e
                fprintf(2, 'Error extracting Hypocotyls from %s\n%s', ...
                    obj.ExperimentName, e.getReport);
                
                if v
                    fprintf('[%.02f sec]\n', toc(t));
                end
            end
        end
        
        function obj = SaveExperiment(obj)
            %% Prune superfluous data, dereference parents, then save
            % Remove RawSeedlings and PreHypocotyls
            g = obj.combineGenotypes;
            arrayfun(@(x) x.PruneSeedlings, g, 'UniformOutput', 0);
            
            s = obj.combineSeedlings;
            arrayfun(@(x) x.PruneHypocotyls, s, 'UniformOutput', 0);
            
            % Save full Experiment object
            
        end
        
        function obj = LoadExperiment(obj)
            %% Recursively set references back to Child objects
            g = obj.combineGenotypes;
            arrayfun(@(x) x.setParent(obj), g, 'UniformOutput', 0);
            
            s = obj.combineSeedlings;
            h = obj.combineHypocotyls;
            
            X = {g, s, h};
            ref = @(c) arrayfun(@(x) x.RefChild, c, 'UniformOutput', 0);
            cellfun(@(x) ref(x), X, 'UniformOutput', 0);
        end
        
        function obj = ChangeBasePath(obj, p)
            %% Change base path to data
            % I'm an idiot and changed the directory to the base data, and it
            % messed up the entire dataset. This should allow flexibility in
            % the path to data.
            
            try
                % Set this object's new name and path
                obj.ExperimentPath = char(p);
                obj.ExperimentName = getDirName(p);
                
                % Iterate through each Genotype's ImageDataStore
                arrayfun(@(x) x.ChangeStorePaths(p), ...
                    obj.Genotypes, 'UniformOutput', 0);
                
            catch e
                fprintf(2, 'Error setting new path\n%s\n', e.message);
            end
        end
        
        function IMGS = PrepareHypocotylImages(obj, SCALE)
            %% Prepare hypocotyl images for CNN
            CRVS = obj.combineContours;
            
            % Resize hypocotyl images to isz x isz
            isz      = ceil(size(CRVS(1).getImage('gray')) * SCALE);
            imgs_raw = arrayfun(@(x) x.getImage('gray'), CRVS, 'UniformOutput', 0);
            imgs_rsz = cellfun(@(x) imresize(x, isz), imgs_raw, 'UniformOutput', 0);
            imgs     = cat(3, imgs_rsz{:});
            imSize   = size(imgs);
            
            % Reshape image data as X values and use Midpoint PCA scores as Y values
            IMGS = double(reshape(imgs, [imSize(1:2), 1, imSize(3)]));
            
        end
        
    end
    
    methods (Access = public)
        %% Various helper methods for other classes to use
        
        function g = getGenotype(obj, idx)
            %% Returns genotype at desired index
            try
                if nargin < 2
                    idx = ':';
                end
                
                g = obj.Genotypes(idx);
            catch e
                fprintf(2, 'No Genotype at index %d\n', idx);
                fprintf(2, '%s \n', e.message);
            end
        end
        
        function G = combineGenotypes(obj)
            %% Combine all Genotypes into single object array
            G = obj.getGenotype(':');
        end
        
        function [g, i] = search4Genotype(obj, nm)
            %% Return specific Genotype by GenotypeName
            gts = obj.getGenotype(':')';
            
            for i = 1 : numel(gts)
                mtc = gts(i).GenotypeName;
                if isequal(nm, mtc)
                    g = gts(i);
                    return;
                end
            end
        end
        
        function S = combineSeedlings(obj)
            %% Combine all Seedlings into single object array
            G = obj.combineGenotypes;
            S = arrayfun(@(x) x.getSeedling(':'), G, 'UniformOutput', 0);
            S = cat(1, S{:});
        end
        
        function H = combineHypocotyls(obj, req)
            %% Combine all Hypocotyls into single object array
            % CHANGE THIS WHEN I FIX HOW HYPOCOTYLS ARE STORED IN SEEDLINGS
            % Each Seedling will have a single Hypocotyl, derived from data
            % from the combination of good frames of each PreHypocotyl.
            S = obj.combineSeedlings;
            
            try
                switch req
                    case 'pre'
                        H = arrayfun(@(x) x.getAllPreHypocotyls, S, 'UniformOutput', 0);
                        H = cat(2, H{:});
                    case 'post'
                        H = arrayfun(@(x) x.MyHypocotyl, S, 'UniformOutput', 0);
                        H = cat(2, H{:});
                    otherwise
                        H = arrayfun(@(x) x.MyHypocotyl, S, 'UniformOutput', 0);
                        H = cat(2, H{:});
                end
            catch
                H = arrayfun(@(x) x.MyHypocotyl, S, 'UniformOutput', 0);
                H = cat(2, H{:});
            end
            
        end
        
        function [D, org, flp] = combineContours(obj, getCrvs)
            %% Return all Hypocotyls with manually-drawn CircuitJB objects
            % Returns both original and flipped versions of each. I'm not sure
            % if it would work if some don't have flipped versions.
            if nargin < 2
                getCrvs = 1;
            end
            
            H   = obj.combineHypocotyls;
            org = arrayfun(@(x) arrayfun(@(y) x.getCircuit(y, 'org'),  ...
                1:x.Lifetime, 'UniformOutput', 0), H, 'UniformOutput', 0);
            org = cat(2, org{:});
            org = cat(1, org{:});
            
            flp = arrayfun(@(x) arrayfun(@(y) x.getCircuit(y, 'flp'),  ...
                1:x.Lifetime, 'UniformOutput', 0), H, 'UniformOutput', 0);
            flp = cat(2, flp{:});
            flp = cat(1, flp{:});
            
            D = [org ; flp];
            
            obj.CurvesTraced = numel(D);
            
            % Return Curves only
            if getCrvs
                D  = arrayfun(@(x) x.Curves, D, 'UniformOutput', 0);
                D  = cat(1, D{:});
            end
        end
        
        function [noflp, hyp] = findMissingContours(obj)
            %% Find missing contours (accidentally cancelled when training)
            C = obj.combineContours;
            D = arrayfun(@(x) x.Curves, C, 'UniformOutput', 0);
            D = cat(1, D{:});
            
            if mod(numel(D),2)
                nms   = arrayfun(@(x) x.Parent.Origin, D, 'UniformOutput', 0);
                hlfSz = ceil(length(nms) / 2);
                org   = nms(1       : hlfSz);
                flp   = nms(hlfSz+1 : end);
                flp{end+1} = '';
                flps  = cellfun(@(x) x(6:end), flp, 'UniformOutput', 0);
                mems  = cellfun(@(x) ismember(x, flps), org, 'UniformOutput', 0);
                mems  = cat(1, mems{:});
            else
                mems = [];
            end
            
            noflp = org{~mems};
            noflp = noflp{1};
            
            % Search for and Return Hypocotyl with missing contour
            [~, exIdx] = regexp(noflp, [ex.ExperimentName , '_']);
            sdIdx = regexp(noflp, '_Seedling');
            gname = noflp(exIdx+1 : sdIdx-1);
            gen   = ex.search4Genotype(gname);
            aa    = strfind(noflp, '{');
            bb    = strfind(noflp, '}');
            hyIdx = str2double(noflp(aa + 1 : bb - 1));
            sdl   = gen.getSeedling(hyIdx);
            hyp   = sdl.MyHypocotyl;
            
            %             x{numel(x) + abs(numel(x) - numel(y))} = '';
        end
        
        function P = combineParameters(obj)
            %% Return all Ppar (theta, dX, dY) from CircuitJB Routes
            C = obj.combineContours;
            P = arrayfun(@(x) x.ParameterRoutes, C, 'UniformOutput', 0);
            P = cat(3, P{:});
            P = permute(P, [3 2 1]);
        end
        
        function check_outOfFrame(obj, frm, s)
            %% Check if Seedling grows out of frame
            %
            % obj: this Experiment
            % frm: frame of time-lapse
            % s  : Seedling to check
            
        end
        
        function prp = getProperty(obj, req)
            %% Return a property from this object
            try
                prp = obj.(req);
            catch
                fprintf(2, 'Error retrieving %s property\n', req);
                prp = [];
            end
        end
    end
    
    %% ------------------------- Private Methods --------------------------- %%
    methods (Access = private)
        %% Private helper methods for this class
        
        
    end
end
