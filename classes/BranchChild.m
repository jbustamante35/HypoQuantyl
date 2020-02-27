%% BranchChild : class for handling BranchPoints from the Skeleton parent class
% Description


classdef BranchChild < handle
    properties (Access = public)
        Parent
        Coordinate
        IndexInSkeleton
        Neighbors
        TotalNeighbors
    end
    
    properties (Access = protected)
    end
    
    %% ------------------------ Main Methods -------------------------------- %%
    methods (Access = public)
        function obj = BranchChild (varargin)
            %% Constructor method to generate a BranchChild object
            if ~isempty(varargin)
                % Parse inputs to set properties
                args = varargin;
            else
                % Set default properties for empty object
                args = {};
            end
            prps   = properties(class(obj));
            deflts = {'Neighbors', ...
                struct('Coordinate', [], 'EndPath', [], 'BranchPath', [])};
            obj    = classInputParser(obj, prps, deflts, args);
            
        end
        
        function FindNeighbors(obj)
            %% Find closest nodes to BranchPoint
            % Use the `successors` function from a digraph to identify graph
            % indices neighboring this branch node
            g     = obj.Graph;
            idx   = obj.IndexInSkeleton;
            nIdxs = g.successors(idx);
            
            % Neighbor to all other branches
            N2E = arrayfun(@(x) obj.neighbor2end(x), ...
                nIdxs, 'UniformOutput', 0);
            N2B = arrayfun(@(x) obj.neighbor2branch(x), ...
                nIdxs, 'UniformOutput', 0);
            
            obj.TotalNeighbors = numel(nIdxs);
            
            %% Remove paths that go through fellow neighbor paths
            ncrds = obj.Parent.Coordinates(nIdxs,:);
            N2E   = arrayfun(@(x) obj.cleanupNeighborPaths(x, ncrds, N2E{x}), ...
                1 : obj.TotalNeighbors, 'UniformOutput', 0);
            N2B   = arrayfun(@(x) obj.cleanupNeighborPaths(x, ncrds, N2B{x}), ...
                1 : obj.TotalNeighbors, 'UniformOutput', 0);                      
            
            for n = 1 : obj.TotalNeighbors
                obj.Neighbors(n).Coordinate = ncrds(n,:);
                obj.Neighbors(n).EndPath    = cell2mat(N2E{n});
                obj.Neighbors(n).BranchPath = cell2mat(N2B{n});
            end
            
        end
        
    end
    
    %% -------------------------- Helper Methods ---------------------------- %%
    methods (Access = public)
        function g = Graph(obj)
            %% Return graph diagram from Parent Skeleton
            try
                g = obj.Parent.Graph;
            catch e
                fprintf(2, 'Error returning Graph\n%s\n', e.getReport);
                g = [];
            end
        end
        
        function n2e = neighbor2end(obj, nIdx)
            % This function should find a single path from the current neighbor
            % to the closest EndPoint AWAY from this object's coordinate. It
            % should remove everything upstream of the parent coordinate
            %
            % 1) Find all paths to End/Branch Points
            % 2) Remove paths that go through the parent node
            
            % Find all paths from neighbor to End/Branch Points
            [~ , N2E] = obj.Parent.node2ends(nIdx);
            
            % Remove paths that go through the parent node
            bcrd     = obj.Coordinate;
            chk4self = cell2mat(cellfun(@(x) isempty(find( ...
                pdist2(x, bcrd) == 0, 1)), N2E, 'UniformOutput', 0));
            n2e      = N2E(chk4self);
        end
        
        function n2b = neighbor2branch(obj, nIdx)
            %% neighbor2branches: get paths from node to end points
            % This function should find a single path from the current neighbor
            % to the closest BranchPoint AWAY from this object's coordinate. It
            % should remove everything upstream of the parent coordinate
            %
            % 1) Find all paths to End/Branch Points
            % 2) Remove paths that go through the parent node
            
            % Find all paths from neighbor to End/Branch Points
            [~ , N2B] = obj.Parent.node2branches(nIdx);
            
            % Remove paths that go through the parent node
            bcrd     = obj.Coordinate;
            chk4self = cell2mat(cellfun(@(x) isempty(find( ...
                pdist2(x, bcrd) == 0, 1)), N2B, 'UniformOutput', 0));
            n2b      = N2B(chk4self);
            
        end
        
        function N = getNeighbor(obj, nIdx, req)
            %% Returns a Neighbor or one or both paths
            try
                switch nargin
                    case 1
                        % Full structure of Neighbors 
                        nIdx = ':';
                        req  = 'none';
                        N    = obj.Neighbors;
                    case 2
                        % Neighbor with both paths
                        req = 'none';
                        N   = obj.Neighbors(nIdx);
                    case 3
                        % Neighbor(s) with requested path
                        if isequal(nIdx, ':')
                            N = arrayfun(@(x) obj.Neighbors(x).(req), ...
                                1 : obj.TotalNeighbors, 'UniformOutput', 0);
                        elseif ismatrix(nIdx)
                            N = arrayfun(@(x) obj.Neighbors(x).(req), ...
                                nIdx, 'UniformOutput', 0);                            
                        else
                            N = obj.Neighbors(nIdx).(req);
                        end
                        
                    otherwise
                        fprintf(2, 'Error with number in inputs [%d]\n', nargin);
                        N = [];
                        return;
                end
            catch
                fprintf(2, 'Error returning %s path from %d Neighbor\n', ...
                    req, nIdx);
                N = [];
            end
        end
        
        function setProperty(obj, prp, val)
            %% Set property for this object
            try
                prps = properties(obj);
                
                if sum(strcmp(prps, prp))
                    obj.(prp) = val;
                else
                    fprintf('Property %s not found\n', prp);
                end
            catch e
                fprintf(2, 'Can''t set %s to %s\n%s', ...
                    prp, string(val), e.getReport);
            end
            
        end
        
    end
    
    %% ------------------------- Private Methods --------------------------- %%
    methods (Access = private)
        function N = cleanupNeighborPaths(~, nIdx, nCrds, N)
            %% Remove overlapping neighbor paths and select shortest            
            % Remove paths from neighbors that go through other neighbor paths
            crd      = nCrds(1 : size(nCrds,1) ~= nIdx,:);
            chk4self = cell2mat(cellfun(@(x) isempty(find( ...
                pdist2(x, crd) == 0, 1)), N, 'UniformOutput', 0));
            N        = N(chk4self);
            
            % Return the shortest path
            % TODO [02.25.2020]: handle cases with equal shortest paths (default
            % selects the first minimum encountered
            [~ , shortIdx] = min(cell2mat(cellfun(@(x) size(x, 1), ...
                N, 'UniformOutput', 0)));
            N = N(shortIdx);
            
        end
    end
    
end


