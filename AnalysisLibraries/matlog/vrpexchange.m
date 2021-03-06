function [loc,TC] = vrpexchange(loc,C,varargin)
%VRPEXCHANGE Two-vertex exchange procedure for VRP improvement.
% [loc,TC] = vrpexchange(loc,C,cap,twin,locfeas,h)
% Two vertices from different loc seqs are simultaneousely exchanged; e.g.,
% vertex m from loc seq i is exchanged with vertex n from loc seq j:
%             loc{i} = [loc{i}(1:m-1) loc{i}(n) loc{i}(m+1:end)]
%             loc{j} = [loc{j}(1:n-1) loc{i}(m) loc{j}(n+1:end)]
%    loc = m-element cell array of m loc seqs (can be infeasible)
%      C = n x n matrix of costs between n vertices
%    cap = {q,Q} = cell array of capacity arguments, where
%              q = n-element vector of vertex demands, with depot q(1) = 0
%              Q = maximum loc seq load
%   twin = {ld,TW} = cell array of time window arguments
%             ld = 1, n, or (n+1)-element vector of load/unload timespans
%             TW = n or (n+1) x 2 matrix of time windows
%                = (n+1)-element cell array, if multiple windows
%locfeas = {'locfeasfun',P1,P2,...} = cell array specifying user-defined
%          function to test the feasibility of a single loc seq
%      h = (optional) handle to vertex plot, e.g., h = PPLOT(XY,'.');
%          use 'Set Pause Time' on figure's Matlog menu to pause plot
%     TC = m-element vector of loc seq costs
%
% See LOCTC for information about the input parameters
%
% Example:
% vrpnc1  % Loads XY, q, Q, ld, and maxTC
% C = dists(XY,XY,2);
% h = pplot(XY,'r.');
% pplot(XY,num2cellstr(1:size(XY,1)))
% [loc,TC] = vrpinsert(C,{q,Q},{ld},{'maxTCfeas',maxTC},[]);
% [loc,TC] = vrpexchange(loc,C,{q,Q},{ld},{'maxTCfeas',maxTC},h);

% Copyright (c) 1994-2014 by Michael G. Kay
% Matlog Version 16 03-Jan-2014 (http://www.ise.ncsu.edu/kay/matlog)

% Input Error Checking ****************************************************
narginchk(1,6)

if length(varargin) < 4, [varargin{length(varargin)+1:4}] = deal([]); end
[cap,twin,locfeas,h] = deal(varargin{:});

try  % Use for error checking and to store input arguments
   [loc,TC] = tsp2opt(loc,C,cap,twin,locfeas);
catch
   errstr = lasterr;
   idx = find(double(errstr) == 10);
   error(errstr(idx(1)+1:end))
end

if isempty(h), h = NaN; end

if (~ishandle(h) && ~isnan(h)) || (ishandle(h) && (length(h) ~= 1 || ...
      ~strcmp(get(h,'Type'),'line') || ...
      ~strcmp(get(h,'LineStyle'),'none') || ...
      length(get(h,'XData')) ~= size(C,1) || ...
      length(get(h,'YData')) ~= size(C,1)))
   error('Invalid handle "h".')
end
% End (Input Error Checking) **********************************************

str = sprintf('VRP Exchange: 2-Opt Improvement, TC = %f',sum(TC));
fprintf('%s\n',str)

if ishandle(h)
   axes(get(h,'Parent'))
   title(str)
   delete(findobj(gca,'Tag','locplot'))
   XY = [get(h,'XData')' get(h,'YData')'];
   if strcmp(get(gca,'Tag'),'proj'), XY = invproj(XY); end
   pplot(loc,XY,'m','Tag','locplot')
   pplot(XY(1,:),'rs','Tag','locplot')
   if isempty(pauseplot('get')), pauseplot(Inf), end
end

done = 0;
Done = false(length(loc));
while ~done
   done = 1;
   for i = 1:length(loc)-1
      for j = i+1:length(loc)
         if Done(i,j), continue, end  % Skip if no change
         for m = 2:length(loc{i})-1
            for n = 2:length(loc{j})-1
               locim = [loc{i}(1:m-1) loc{j}(n) loc{i}(m+1:end)];
               [locim,TCim] = tsp2opt(locim);
               if isfinite(TCim)
                  locjn = [loc{j}(1:n-1) loc{i}(m) loc{j}(n+1:end)];
                  [locjn,TCjn] = tsp2opt(locjn);
                  if TCim + TCjn < TC(i) + TC(j)
                     loc{i} = locim; loc{j} = locjn;
                     TC(i) = TCim; TC(j) = TCjn;
                     done = 0;
                     Done([i j],:) = 0; Done(:,[i j]) = 0;
                     
                     str = sprintf(['VRP Exchange: Loc(Vtx) %d(%d) ' ...
                           'and %d(%d), TC = %f'],...
                           i,loc{i}(m),j,loc{j}(n),sum(TC));
                     fprintf('%s\n',str)
                     
                     if ishandle(h)
                        title(str)
                        delete(findobj(gca,'Tag','locplot'))
                        pplot(loc,XY,'m','Tag','locplot')
                        pauseplot
                     end
                     
                     break
                  end
               end
            end % n
            if ~done, break, end
         end % m
         if done, Done(i,j) = 1; end  % No improvement
         if ~done, break, end
      end % j
      if ~done, break, end
   end % i
end

if ishandle(h)
   str = sprintf('VRP Exchange: Final TC = %f and %d Loc Seqs',...
      sum(TC),length(TC));
   fprintf('%s\n\n',str)
   title(str)
   delete(findobj(gca,'Tag','locplot'))
   pplot(XY(1,:),'rs','Tag','locplot')
   pplot(loc,XY,'m','Tag','locplot')
   pauseplot
end
