classdef FlowNetwork < Network
    %FLOWNETWORK Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    %^name
    %^instanceID
    %^X
    %^Y
    %^Z
    FlowNodeList % [instanceID, X, Y]
    FlowNodeSet  %NodeSet@FlowNetwork %Use set method to "override" and type check for Flow Network
    FlowEdgeList %[instanceID sourceFlowNode targetFlowNode grossCapacity flowFixedCost]
    FlowEdgeSet % flow edges within the flow network
    
    %Commodity flow in/outbound to Flow Network
    produces@Commodity %{ordered}
    consumes@Commodity %{ordered}
    productionRate %{ordered} by produces
    consumptionRate %{ordered} by consumes
    consumptionProductionRatio %default is eye(numCommodity)
    
    %Commodity flow within Network
    commoditySet@Commodity %{ordered}
    commodityList
    flowAmount %{ordered} by commoditySet
    flowCapacity %{ordered} by commoditySet
    grossCapacity
    flowFixedCost
    flowUnitCost %{ordered} by commoditySet
    
    %2/23/18: Can't redefine property type in subclass
    inFlowEdgeSet@FlowEdge %A set of flow edges incoming to the flow network
    outFlowEdgeSet@FlowEdge %A set of flow edges outgoing to the flow network
    builder %lightweight delegate to builderClass for constructing simulation 
    
    %2/8/19 -- to be deprecated or made private
    FlowNode_ConsumptionProduction %FlowNode Commodity Production/Consumption
    FlowEdge_flowTypeAllowed %FlowEdgeID sourceFlowNode targetFlowNode commodity flowUnitCost
    FlowEdge_Solution %Binary FlowEdgeID sourceFlowNode targetFlowNode grossCapacity flowFixedCost
    commodityFlow_Solution %FlowEdgeID origin destination commodity flowUnitCost flowQuantity
    nodeMapping
    end
    
    methods
        function self=FlowNetwork(varargin)
          if nargin==0
            % default constructor
          end
        end
        
        function addEdge(self, edgeSet)
            self.inFlowEdgeSet = findobj(edgeSet, 'targetFlowNetworkID', self.instanceID);
            self.outFlowEdgeSet = findobj(edgeSet, 'sourceFlowNetworkID', self.instanceID);
        end
        
        function setNodeSet(self, nodes)
            if isa(nodes, 'FlowNetwork')
                self.NodeSet = nodes;
            else
                error('NodesSet for FlowNetwork must be of type Flow Network');
            end
        end
        
        function setBuilder(self, builder)
            %assert(isa(builder, 'IFlowNetworkBuilder') == 1, 'Invalid Builder Object')
            self.builder = builder;
            self.builder.systemElement = self;
        end
        
        function plotMFNSolution(FN,varargin)
            import AnalysisLibraries/matlog.*
            
            gplot(list2adj(FN.commodityFlowPath(:,1:2)), FN.FlowNodeSet(:,2:3))
            hold on;
            if length(varargin) == 2
                customerSet = varargin{1};
                depotSet = varargin{2};
                scatter(customerSet(:,2),customerSet(:,3))
                scatter(depotSet(:,2),depotSet(:,3), 'filled')
            else
                scatter(FN.FlowNodeSet(:,2),FN.FlowNodeSet(:,3), 'filled')
            end
            hold off;
        end
        
        function list2Class(FN)
            %This function should convert the list based flow network into
            %a class based representation; more or less a constructor for a
            %flow network from instance data set
            %TO DO: 
        end
       
        function mapFlowNodes2ProductionConsumptionList(self)
            
            numCommodity = length(self.commoditySet);
            FlowNode_ConsumptionProduction = zeros(length(self.FlowNodeList)*numCommodity,3);
            
            for kk = 1:numCommodity
                FlowNode_ConsumptionProduction((kk-1)*length(self.FlowNodeList(:,1))+ 1: kk*length(self.FlowNodeList(:,1)),:) ...
                                = [self.FlowNodeList(:,1), kk*ones(length(self.FlowNodeList(:,1)),1), ...
                                  zeros(length(self.FlowNodeList(:,1)),1)];
            end
            
            
            for ii = 1:length(self.FlowNodeSet)
                %FlowNodeSet is type cell with each cell containing a set
                %of Flow Nodes (of a particular type)
                for jj = 1:length(self.FlowNodeSet{ii})
                    for kk = 1:length(self.FlowNodeSet{ii}(jj).produces)
                        index = FlowNode_ConsumptionProduction(:,1) == self.FlowNodeSet{ii}(jj).instanceID & FlowNode_ConsumptionProduction(:,2) == self.FlowNodeSet{ii}(jj).produces(kk).instanceID;
                        FlowNode_ConsumptionProduction(index,3) = self.FlowNodeSet{ii}(jj).productionRate(kk);
                    end %for each commodity that flowNode 'produces'
                    
                    for kk = 1:length(self.FlowNodeSet{ii}(jj).consumes)
                        index = FlowNode_ConsumptionProduction(:,1) == self.FlowNodeSet{ii}(jj).instanceID & FlowNode_ConsumptionProduction(:,2) == self.FlowNodeSet{ii}(jj).consumes(kk).instanceID;
                        FlowNode_ConsumptionProduction(index,3) = -1*self.FlowNodeSet{ii}(jj).consumptionRate(kk);
                    end %for each commodity that flowNode 'consumes'
                end % for each Flow Node
            end % for each Flow Node
            
            self.FlowNode_ConsumptionProduction = FlowNode_ConsumptionProduction;
        end
        
        function mapFlowEdges2FlowTypeAllowed(self)
            %FlowEdge_flowTypeAllowed: FlowEdgeID origin destination commodityKind flowUnitCost
            
            numArc = length(self.FlowEdgeSet);
            numCommodity = length(self.commoditySet);
            FlowEdge_flowTypeAllowed = zeros(numArc*numCommodity, 5);
            
            for ee = 1:length(self.FlowEdgeSet)
                numCommodity = length(self.FlowEdgeSet(ee).flowTypeAllowed);
                ID = [self.FlowEdgeSet(ee).instanceID, self.FlowEdgeSet(ee).sourceFlowNetworkID, self.FlowEdgeSet(ee).targetFlowNetworkID];
                FlowEdge_flowTypeAllowed((ee-1)*numCommodity+1:(ee)*numCommodity,:) = ...
                            [repmat(ID, [numCommodity,1]), self.FlowEdgeSet(ee).flowTypeAllowed', self.FlowEdgeSet(ee).flowUnitCost'];
            end
            
            self.FlowEdge_flowTypeAllowed = FlowEdge_flowTypeAllowed(FlowEdge_flowTypeAllowed(:,1) > 0,:);
        end
        
        function transformCapacitatedFlowNodes(self)
           % a) Transform capacitated flow nodes
            numCommodity = length(self.commoditySet);
            flowEdgeList = self.FlowEdgeList;
            flowNodeList = self.FlowNodeList;
            FlowEdge_flowTypeAllowed = self.FlowEdge_flowTypeAllowed;
            FlowNode_ConsumptionProduction = self.FlowNode_ConsumptionProduction;
            gg = max(flowEdgeList(:,1))+1;

            % Split capacitated node, add capacity and 'cost of opening' to edge
            for jj = 1:length(self.FlowNodeSet)
                capacitatedNodeSet = findobj(self.FlowNodeSet{jj}, '-not', 'grossCapacity', inf);
                for ii =1:length(capacitatedNodeSet)
                    nodeInstanceID = capacitatedNodeSet(ii).instanceID;
                    newInstanceID = max(flowNodeList(:,1))+1;
                    flowNodeList(end+1,:) = [newInstanceID, capacitatedNodeSet(ii).X, capacitatedNodeSet(ii).Y];
                    nodeMapping(ii,:) = [nodeInstanceID, newInstanceID];

                    %Replace all origin nodes with newly created node
                    flowEdgeList(flowEdgeList(:,2) == nodeInstanceID, 2) = newInstanceID;
                    FlowEdge_flowTypeAllowed(FlowEdge_flowTypeAllowed(:,2) == nodeInstanceID,2) = newInstanceID;


                    %2/9/19 assume all commodities can flow through all depots
                    %TO DO: only add edge/commodity flow variable for commodities
                    %that can flow (and allow for productionCode for flowUnitCost
                    %FlowEdge_flowTypeAllowed: FlowEdgeID origin destination commodityKind flowUnitCost

                    flowEdgeList(end+1,:) = [gg, nodeInstanceID, newInstanceID, capacitatedNodeSet(ii).grossCapacity, capacitatedNodeSet(ii).fixedCost];
                    FlowEdge_flowTypeAllowed(end+1:end+numCommodity, :) = [repmat(flowEdgeList(end,1:3), numCommodity,1), [1:numCommodity]', zeros(numCommodity,1)];
                    FlowNode_ConsumptionProduction(end+1:end+numCommodity,:) = [newInstanceID*ones(numCommodity,1), [1:numCommodity]', zeros(numCommodity,1)];

                    %Add split capacitated flow node to flowTypeAllowed list
                    %FlowEdge_flowTypeAllowed(end+1:end+numCommodity,:) = [repmat(flowEdgeList(end,1:3), numCommodity,1),kk*ones(numCommodity,1), zeros(numCommodity,1)];

                    gg = gg +1;
                end
            end

            self.FlowEdge_flowTypeAllowed = FlowEdge_flowTypeAllowed;
            self.FlowEdgeList = flowEdgeList;
            %2/9/19 -- The optimization algorithm is going to add flow balance
            %constraints based on consumption/production, where the flow nodes are
            %the variables. So the ConsumptionProduction data needs to be sequenced
            %by commodityKind first then NodeID.
            % -- Alternatively, could inject the new consumption/production rows
            % (associated with the split node) into the array where they belong
            % (contiguous with the other rows associated with that commodityKind)
            %FlowNode_ConsumptionProduction = FlowNode_ConsumptionProduction(any(FlowNode_ConsumptionProduction,2),:);
            [~,I] = sort(FlowNode_ConsumptionProduction(:,2));
            FlowNode_ConsumptionProduction = FlowNode_ConsumptionProduction(I,:);
            self.FlowNode_ConsumptionProduction = FlowNode_ConsumptionProduction;
            self.FlowNodeList = flowNodeList;
            self.nodeMapping = nodeMapping;
        end
        
        function mapFlowNetwork2MCFNOPT(self)
            self.mapFlowNodes2ProductionConsumptionList;
            self.mapFlowEdges2FlowTypeAllowed;
            self.transformCapacitatedFlowNodes;
        end
        
        function mapMCFNSolution2FlowNetwork(self)
            
            %% Transform Capacitated Nodes
            % 1) Find capacitated nodes that were selected
            capacitatedNodeSelection = self.FlowEdge_Solution(ismember(self.FlowEdge_Solution(:, 3:4), self.nodeMapping,'rows'),:);
            
            % 2) Remove split nodes from FlowNodeList
            self.FlowNodeList(ismember(self.FlowNodeList(:,1), self.nodeMapping(:,2)),:) = [];
            
            % 3) Find and replace InstanceIDs of split nodes
            for ii = 1:length(self.nodeMapping)
                self.FlowEdgeList(self.FlowEdgeList(:,2) ==  self.nodeMapping(ii,2),2) = self.nodeMapping(ii,1);
            end
            
            % 4) Remove the 
            self.FlowEdgeList(ismember(self.FlowEdgeList(:, 2:3), self.nodeMapping,'rows'),:) = [];
            
            %% Remove unselected Flow Nodes
            % 1) Remove not selected from FlowNodeList
            for ii = 1:length(capacitatedNodeSelection(:,1))
                if capacitatedNodeSelection(ii,1) == 0
                   self.FlowNodeList(self.FlowNodeList(:,1) == capacitatedNodeSelection(ii,3),:) = [];
                end
            end
            
            % 2) Remove not selected from FlowNodeSet
            for ii = 1:length(self.FlowNodeSet)
                jj = 1;
                while jj <= length(self.FlowNodeSet{ii})
                    instanceID = self.FlowNodeSet{ii}(jj).instanceID;
                    isSelected = capacitatedNodeSelection(capacitatedNodeSelection(:,3)==instanceID,1);
                    if ~isSelected
                        self.FlowNodeSet{ii}(jj) = [];
                    else
                        jj = jj +1;
                    end
                end
            end
            
            %% Remove Unselected FlowEdges
            selectedEdges = logical(self.FlowEdge_Solution(1:length(self.FlowEdgeList),1));
            self.FlowEdgeList = self.FlowEdgeList(selectedEdges,:);
            self.FlowEdgeSet = self.FlowEdgeSet(selectedEdges); 
            
            % Add flow edge sets to each flow node
            for ii = 1:length(self.FlowNodeSet)
                for jj = 1:length(self.FlowNodeSet{ii})
                    self.FlowNodeSet{ii}(jj).inFlowEdgeSet = findobj(self.FlowEdgeSet, 'targetFlowNetworkID', self.FlowNodeSet{ii}(jj).instanceID);
                    self.FlowNodeSet{ii}(jj).outFlowEdgeSet = findobj(self.FlowEdgeSet, 'sourceFlowNetworkID', self.FlowNodeSet{ii}(jj).instanceID);
                end
            end
            
            %% Add selected commodities
            % 1) Add to flow edges
            commodityFlow_Solution = self.commodityFlow_Solution;
            commoditySet = self.commoditySet;
            for ii = 1:length(self.FlowEdgeSet)
                %filter to commodity on specified edge
                edgeXCommodity = commodityFlow_Solution(commodityFlow_Solution(:,1) == self.FlowEdgeSet(ii).instanceID,:);
                self.FlowEdgeSet(ii).flowTypeAllowed = edgeXCommodity(:,4)'; %should flow type allowed be commodities?
                self.FlowEdgeSet(ii).flowUnitCost = edgeXCommodity(:,5)';
                self.FlowEdgeSet(ii).flowAmount = edgeXCommodity(:,6)';
                %May add later to add the flow solution as the flow capacity per commodity kind
            end % for each flow edge in flowEdgeSet
            
            % 2) Add to flow nodes
            for ii = 1:length(self.FlowNodeSet)
                for jj = 1:length(self.FlowNodeSet{ii})
                    sourceXCommodity = commodityFlow_Solution(commodityFlow_Solution(:,2) == self.FlowNodeSet{ii}(jj).instanceID,:);
                    targetXCommodity = commodityFlow_Solution(commodityFlow_Solution(:,3) == self.FlowNodeSet{ii}(jj).instanceID,:);
                    
                    self.FlowNodeSet{ii}(jj).productionRate = sourceXCommodity(:, 6);
                    self.FlowNodeSet{ii}(jj).consumptionRate = targetXCommodity(:, 6);
                    
                    produces = Commodity.empty;
                    for kk = 1:length(sourceXCommodity(:,1))
                        produces(end+1) = findobj(commoditySet, 'instanceID', sourceXCommodity(kk,4));
                    end
                    self.FlowNodeSet{ii}(jj).produces = produces;
                    
                    %We're going to repurpose the produces variable now to fill out the commoditySet
                    consumes = Commodity.empty;
                    for kk = 1:length(targetXCommodity(:,1))
                        consumes(end+1) = findobj(commoditySet, 'instanceID', targetXCommodity(kk,4));
                        
                        %Check to see if the commodity is in the commodity set (repurposed produces variable)
                        if isempty(findobj(produces, 'instanceID', targetXCommodity(kk,4)))
                            produces(end+1) = consumes(end);
                        end
                    end
                    self.FlowNodeSet{ii}(jj).consumes = consumes;
                    self.FlowNodeSet{ii}(jj).commoditySet = produces;
                end %for each node in flow node set (inner)
            end %for each node in flow node set (outer)
            
            % 3) Build commodity routes
            %TO DO: consider the case with BOM where the same input part is sourced from two different suppliers
            % It has to be represented with the same commodity, but has different route.
            for ii = 1:length(self.commoditySet)
                instanceID = self.commoditySet(ii).instanceID;
                self.commoditySet(ii).Route = self.buildCommodityRoute(commodityFlow_Solution(commodityFlow_Solution(:,4) == instanceID,2:6));
            end
            
            % 4) Build probabilistic routing
            for ii = 1:length(self.FlowNodeSet)
                for jj = 1:length(self.FlowNodeSet{ii})
                    totalOutFlow = 0;
                    edgeFlowAmount = [];
                    for kk = 1:length(self.FlowNodeSet{ii}(jj).outFlowEdgeSet)
                        edgeFlowAmount(end+1) = sum(self.FlowNodeSet{ii}(jj).outFlowEdgeSet(kk).flowAmount);
                        totalOutFlow = totalOutFlow + edgeFlowAmount(end);
                    end
                    self.FlowNodeSet{ii}(jj).routingProbability = edgeFlowAmount./totalOutFlow;
                end
            end
            
            
        end %mapMCFNSolution2FlowNetwork
        
        function route = buildCommodityRoute(self, commodityFlowSolution)
        %Commodity_Route is a set of arcs that the commodity flows on
        %need to assemble the arcs into a route or path
            ii = 1;
            route = commodityFlowSolution(ii,1:2);
            while sum(commodityFlowSolution(:,1) == commodityFlowSolution(ii,2))>0
                ii = find(commodityFlowSolution(:,1) == commodityFlowSolution(ii,2));
                if eq(commodityFlowSolution(ii,4),0)==0
                    route = [route, commodityFlowSolution(ii,2)];
                end
            end
            %NOTE: Need a better solution to '10', it should be 2+numDepot
            while length(route)<6
                route = [route, 0];
            end
       end  %end build commodity route
    
    end
end
