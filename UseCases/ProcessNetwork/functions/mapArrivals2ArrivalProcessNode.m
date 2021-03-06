function [arrivalProcess, arrivalEdgeSet] = mapArrivals2ArrivalProcessNode(processSet, edgeSet, productArrivalRate, processPlanSet)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

nProcess = length(processSet);
nProd = length(productArrivalRate);
totalArrivalRate = sum(productArrivalRate);
externalArrivalRate = zeros(nProcess, 1); %total commodity flow into each process node

for ii = 1:nProd
    externalArrivalRate(processPlanSet(ii,1)) = externalArrivalRate(processPlanSet(ii,1)) + productArrivalRate(ii);
end

arrivalProcess = Process;
arrivalProcess.instanceID = nProcess+1;
arrivalProcess.name = 'Arrival_Process';
arrivalProcess.typeID = 'ArrivalProcess';
arrivalProcess.concurrentProcessingCapacity = inf;
arrivalProcess.averageServiceTime = 1/totalArrivalRate;
arrivalProcess.storageCapacity = inf;
arrivalProcess.routingProbability = externalArrivalRate ./ totalArrivalRate;

arrivalEdgeSet(nProcess) = FlowNetworkLink;
for ii = 1:nProcess
    arrivalEdgeSet(ii).instanceID = length(edgeSet)+ ii;
    arrivalEdgeSet(ii).sourceFlowNetworkID = arrivalProcess.instanceID;
    arrivalEdgeSet(ii).sourceFlowNetwork = arrivalProcess;
    arrivalEdgeSet(ii).targetFlowNetworkID = processSet(ii).instanceID;
    arrivalEdgeSet(ii).targetFlowNetwork = processSet(ii);
    arrivalEdgeSet(ii).typeID = 'Job';
    
    %Find product's who's first process step is process ii (this)
    idx = find(processPlanSet(:,1) == ii); 
    arrivalEdgeSet(ii).flowTypeAllowed = idx;
    arrivalEdgeSet(ii).flowAmount = productArrivalRate(idx);
    %arrivalEdgeSet(ii).flowAmount = arrivalProcess.routingProbability(ii)*100;

    
end

end

