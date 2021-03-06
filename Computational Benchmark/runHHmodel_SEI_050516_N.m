% Set up the data
clearvars

% Load true value calculated by running ODE45 with strict tolerance 1e-13
true = load('TrueValue_Homo_Ns','P');
pTrue = true.P; clear true

% Set up transmission parameter within the household
b = 0.1;
alpha = 0.663;
gamma = 0.025;

% Tolerance
tol = 1e-8;
h = 1;

% Transmission between households
% tau = 0.0047;
tau = 0;

% Initialise counter
NN = [2:2:60 70 80 90];

% Do replicates
REP = 10;

for jj = 1:REP
    
    for ii = 1:length(NN)
        
        handd = sprintf('Replicate %d of %d. Size (N=%d) %d of %d',jj,REP,NN(ii),ii,length(NN));
        disp(handd)
        
        N = NN(ii);
        
        beta = b/((N-1)^alpha); %#ok<*PFOUS>
        
        % Create the generator matrix
        [Q,HHconfig] = SEI(N); %#ok<*AGROW>
        
        % Store the matrix size
        matsize(ii,1,jj) = length(HHconfig.dataI(:,1)); 
        
        ppTrue = pTrue(ii).PP;
        ppTrue = abs(ppTrue);
        ppTrue = ppTrue/sum(ppTrue);
        
        % Generate the initial conditions vector
        tempI = find(HHconfig.dataI(:,3)==1); tempS = find(HHconfig.dataI(:,1)==N-1);
        pos = intersect(tempI,tempS);
        P0 = zeros(length(HHconfig.dataI(:,1)),1); P0(pos,1) = 1;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ODE4
        % Runge-Kutta order 4 with a fixed time step
        f = @(t,x)GenMatrixCalc(Q,beta,tau,gamma,HHconfig,x,N)*x;
        timeC = 0:h:365;
        tic;
        P = ode4(f,timeC,P0); %,odeset('RelTol',tol,'NonNegative',1:length(P0)));
        timeD(ii,1,jj) = toc;
        pODE4 = abs(P(end,:)); % Renormalise this
        pODE4 = pODE4/sum(pODE4);
        tolerance(ii,1,jj) = kl_Div(ppTrue,pODE4);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DA order 1
        % DA Method order 1
        order  = 1;
        %h = 10;
        II = eye(length(HHconfig.dataI(:,1)),length(HHconfig.dataI(:,1)));
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N);
        tic;
        pDA_1 = daMethodTime(h,II,Mfull,365,order,P0,beta,tau,gamma,HHconfig,N,Q);
        timeD(ii,2,jj) = toc;
        tolerance(ii,2,jj) = kl_Div(ppTrue,pDA_1(end,:));
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Cheby
        % Cheby expansion
        timeC = 0:h:365;
        tic;
        for i = 2:length(timeC)
            pCheb(:,i) = polycheby2(Mfull*timeC(i), P0, tol, 2850, min(diag(Mfull*timeC(i))), max(diag(Mfull*timeC(i))));
            Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,pCheb(:,i),N);
        end
        timeD(ii,3,jj) = toc;
        % pCheb(pCheb<0) = 0;
        pCheb(:,1) = P0;
        pCheb = pCheb';
        pChebEnd = pCheb(end,:);
        pChebEnd = abs(pChebEnd)/sum(abs(pChebEnd));
        tolerance(ii,3,jj) = kl_Div(ppTrue,pChebEnd);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Expokit
        % Expokit - Krylov Subspace Approximation
        timeC = 0:h:365;
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N);
        tic;
        for i = 2:length(timeC)
            pExp(:,i) = mexpv(timeC(i), Mfull, P0, tol);
            Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,pExp(:,i),N);
        end
        timeD(ii,4,jj) = toc;
        pExp(:,1) = P0;
        pExp = pExp';
        pExpEnd = pExp(end,:);
        pExpEnd = abs(pExpEnd)/sum(abs(pExpEnd));
        tolerance(ii,4,jj) = kl_Div(ppTrue,pExpEnd);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DA order 2
        % DA Method order 2
        order  = 2;
        %h = 10;
        II = eye(length(HHconfig.dataI(:,1)),length(HHconfig.dataI(:,1)));
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N);
        tic;
        pDA_2 = daMethodTime(h,II,Mfull,365,order,P0,beta,tau,gamma,HHconfig,N,Q);
        timeD(ii,5,jj) = toc;
        % pDA_2(pDA_2<0) = 0;
        pDA_2End = pDA_2(end,:);
        pDA_2End = abs(pDA_2End)/sum(abs(pDA_2End));
        tolerance(ii,5,jj) = kl_Div(ppTrue,pDA_2End);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Mohy & Higham et al 2009
        % Mohy and Higham new scaling and squaring algorithm for the matrix exponential
        timeC = 0:h:365;
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N);
        tic;
        for i = 2:length(timeC)
            pExp_new(:,i) = mexpv_new(timeC(i), Mfull, P0, tol);
            Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,pExp_new(:,i),N);
        end
        timeD(ii,6,jj) = toc;
        pExp_new(:,1) = P0;
        pExp_new = pExp_new';
        pExp_newEnd = pExp_new(end,:);
        pExp_newEnd = abs(pExp_newEnd)/sum(abs(pExp_newEnd));
        tolerance(ii,6,jj) = kl_Div(ppTrue,pExp_newEnd);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DA order 3
        % This is the backward Euler order 3
        order  = 3;
        II = eye(length(HHconfig.dataI(:,1)),length(HHconfig.dataI(:,1)));
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N);
        tic;
        pDA_3 = daMethodTime(h,II,Mfull,365,order,P0,beta,tau,gamma,HHconfig,N,Q);
        timeD(ii,7,jj) = toc;
        pDA_3End = pDA_3(end,:);
        pDA_3End = abs(pDA_3End)/sum(abs(pDA_3End));
        tolerance(ii,7,jj) = kl_Div(ppTrue,pDA_3End);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Mohy & Higham 2010
        timeC = 0:h:365;
        Mfull = GenMatrixCalc(Q,beta,tau,gamma,HHconfig,P0,N); % Calculates the Q matrix
        tic;
        for i = 2:length(timeC)
            [pNew(:,i),s,m,mv,mvd,unA] = expmv_2010(timeC(i),Mfull,P0,[],'single');     %#ok<*SAGROW>
        end
        timeD(ii,8,jj) = toc;
        pNew(:,1) = P0;
        pNew = pNew';
        pNew_end = pNew(end,:);
        pNew_end = abs(pNew_end)/sum(abs(pNew_end));
        tolerance(ii,8,jj) = kl_Div(ppTrue,pNew_end);
        
        % Clear potential mismatches in dimension
        clear pCheb pExp pExp_new pNew
        
    end
    
    % Saves the outerloop results i.e. for each replicate
    save outerLoop
    
end

save ModelRunsReplicates_N_SSSD