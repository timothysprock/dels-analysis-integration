%% 0) Generate Random Instance of Distribution Network
dn1 = DistributionFlowNetworkGenerator;

%% 1) Build and Solve Desteriministic MCFN
%GenerateFlowNetworkSet implements a leave one out heuristic to generate a
%family of candidate MCFN solutions
flowNetworkSet = GenerateFlowNetworkSet(dn1, dn1.depotSet(1:length(dn1.depotSet)/2,:), dn1.depotFixedCost);

%% 2) MAP MCFN Solution to Distribution System Model
distributionNetworkSet(length(flowNetworkSet)) = DistributionNetwork(dn1);
distributionNetworkSet(1) = dn1;
clear dn1;

for ii = 1:length(distributionNetworkSet)
    distributionNetworkSet(ii).mapFlowNetwork2DistributionNetwork;
end
clear flowNetworkSet ii;

%% 3) Build and Run Low-Fidelity Simulations
flowNetworkFactorySet(length(distributionNetworkSet)) = FlowNetworkFactory;
for ii = 1:length(distributionNetworkSet)
    % Build & Run Simulations

    flowNetworkFactorySet(ii).Model = 'Distribution';
    flowNetworkFactorySet(ii).modelLibrary = 'Distribution_Library';
    
    %Instantiate and set builder helper classes for each flow network
    depotBuilder = IDepotBuilder;
    for jj = 1:length(distributionNetworkSet(ii).depotNodeSet)
        distributionNetworkSet(ii).depotNodeSet(jj).setBuilder(depotBuilder);
    end
    
    flowNetworkFactorySet(ii).addFlowNode(distributionNetworkSet(ii).transportationChannelNodeSet)
    flowNetworkFactorySet(ii).addFlowNode(distributionNetworkSet(ii).depotNodeSet)
    flowNetworkFactorySet(ii).addFlowNode(distributionNetworkSet(ii).customerNodeSet)
    flowNetworkFactorySet(ii).addFlowEdge(distributionNetworkSet(ii).edgeSet)
    flowNetworkFactorySet(ii).buildSimulation;
    
    %TO DO: Transition GA opt to a distributionNetwork based interface
    %distributionNetworkSet(ii).resourceSolution = MultiGA_Distribution(model, distributionNetworkSet(ii).customerNodeSet, distributionNetworkSet(ii).depotNodeSet, 1000*ones(length(distributionNetworkSet(ii).depotNodeSet),1), [], 'true');
    clear MultiGA_Distribution;
    strcat('complete: ', num2str(ii))
end
    clear depotBuilder ii jj;
%% 4) ReBuild Hi-Fidelity Simulation 
for ii = 1:length(distributionNetworkSet)
       
    for jj = 1:length(distributionNetworkSet(ii).customerNodeSet)
        distributionNetworkSet(ii).customerNodeSet(jj).Type = 'Customer'; %Change Resolution from Probabilistic to Complete
        distributionNetworkSet(ii).customerNodeSet(jj).setCommoditySet(distributionNetworkSet(ii).commoditySet);
    end
    
    for jj = 1:length(distributionNetworkSet(ii).depotNodeSet)
        distributionNetworkSet(ii).depotNodeSet(jj).Type = 'Depot';
    end
    
end 

%% 5) Build and Run High-Fidelity Simulations
for ii = 1:length(distributionNetworkSet)
    flowNetworkFactorySet(ii).buildSimulation;

    %distributionNetworkSet(ii).policySolution = Distribution_Pareto(model, distributionNetworkSet(ii).customerNodeSet, distributionNetworkSet(ii).depotNodeSet, distributionNetworkSet(ii).transportationNodeSet, distributionNetworkSet(ii).resourceSolution, 1000*ones(length(distributionNetworkSet(ii).resourceSolution(1,:)),1));
    %save GenerateFamily.mat;
    strcat('complete: ', num2str(ii))
end

%% Pareto Analysis

TravelDist = [reshape(distributionNetworkSet(1).policySolution(:,:,1), [],1); reshape(distributionNetworkSet(2).policySolution(:,:,1), [],1); reshape(distributionNetworkSet(3).policySolution(:,:,1), [],1); reshape(distributionNetworkSet(4).policySolution(:,:,1), [],1); reshape(distributionNetworkSet(5).policySolution(:,:,1), [],1)];
ResourceInvestment =  [reshape(distributionNetworkSet(1).policySolution(:,:,3), [],1); reshape(distributionNetworkSet(2).policySolution(:,:,3), [],1); reshape(distributionNetworkSet(3).policySolution(:,:,3), [],1); reshape(distributionNetworkSet(4).policySolution(:,:,3), [],1); reshape(distributionNetworkSet(5).policySolution(:,:,3), [],1)];
ServiceLevel =  1.-[reshape(distributionNetworkSet(1).policySolution(:,:,2), [],1); reshape(distributionNetworkSet(2).policySolution(:,:,2), [],1); reshape(distributionNetworkSet(3).policySolution(:,:,2), [],1); reshape(distributionNetworkSet(4).policySolution(:,:,2), [],1); reshape(distributionNetworkSet(5).policySolution(:,:,2), [],1)];
paretoI = paretoGroup([TravelDist, ResourceInvestment, ServiceLevel]);

scatter3( TravelDist(paretoI), ResourceInvestment(paretoI), 1.-ServiceLevel(paretoI));

warning('on','all');