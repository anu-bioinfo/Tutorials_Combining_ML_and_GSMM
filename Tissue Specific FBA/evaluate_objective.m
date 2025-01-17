function [v_out, f_out] = evaluate_objective(x, fbamodel, genes, reaction_expression, pos_genes_in_react_expr, ixs_genes_sorted_by_length, gamma)
warning off
yt=x';      % x' is the transpose of x, that is the gene expression array

eval_reaction_expression = reaction_expression;

%indices are sorted by length of their string, so the longest get replaced first. This avoids, for example, that if we have two genes 123.1 and 23.1, the substring '23.1' is replaced in both. If we first replace the longest and finally the shortest, this problem is avoided

for i=ixs_genes_sorted_by_length %loop over the array of the non-1 gene expressions, in order to replace the names of genes in geni_reazioni.mat with their values. All the gene set expressions with only 1s as gene values , will be left empty and at the end of this loop everything empty will be substituted with 1 anyway. This avoids looping over all the genes yt, which is very expensive
    position_gene = pos_genes_in_react_expr{i};
    for j=1:length(position_gene)      %for each string of reaction_expression, we replace the substring 'bXXXX' with the number representing its gene expression
        eval_reaction_expression{position_gene(j)} = strrep(eval_reaction_expression{position_gene(j)}, genes{i}, num2str(yt(i),'%.15f'));  %Matlab strangely truncates decimal digits when using num2str. Addimg %.12f at least ensures that 12 decimal digits are included in the number converted into string
    end
end
eval_reaction_expression( cellfun(@isempty, eval_reaction_expression) ) = {'1.0'};  %replaces all the empty cells of gene expression (e.g. exchange reactions) with 1, i.e. gene expressed nomally

% for i=1:numel(eval_reaction_expression)
%     for j=1:numel(genes) %in the eval_reaction_expression in which already all the non-1 genes have been substituted with their values, we now have to substitute all the remaining genes with the number 1
%         eval_reaction_expression{i} = strrep(eval_reaction_expression{i}, ['/' geni{j} '/'], '1.0');  %we do this job only for the non-1 reaction expressions, so we save a lot of computational time. Note that we need '1.0' because the regecpr below is looking for NUM.NUM strings, and therefore putting only '1' will give an infinite loop
%     end
% end

%eval_reaction_expression( cellfun(@isempty, eval_reaction_expression) ) = {'1'};  %replaces all the empty cells of gene expression (e.g. exchange reactions or reactions whose genes have all gene expression 1) with 1, i.e. gene expressed nomally

num_reaction_expression = zeros(1,length(eval_reaction_expression));
%gamma = zeros(1,length(reaction_expression));

for i=1:length(num_reaction_expression)
    str = eval_reaction_expression{i};
    
    num_parenthesis = numel(strfind(str,')'));
    while (num_parenthesis > 32) %if there are more than 32 parentheses, matlab is unable to run EVAL. So we need to reduce these parentheses manually by starting to eval smaller pieces of the string
        to_replace = 'min.\d*+\.+\d*,\d*+\.+\d*.|max.\d*+\.+\d*,\d*+\.+\d*.|min..\d*+\.+\d*.,\d*+\.+\d*.|max..\d*+\.+\d*.,\d*+\.+\d*.|min..\d*+\.+\d*.,.\d*+\.+\d*..|max..\d*+\.+\d*.,.\d*+\.+\d*..|min.\d*+\.+\d*,.\d*+\.+\d*..|max.\d*+\.+\d*,.\d*+\.+\d*..';  %searches for all the strings of kind min(NUM.NUM,NUM.NUM) or max(NUM.NUM,NUM.NUM) or  min((NUM.NUM),NUM.NUM) or max((NUM.NUM),NUM.NUM) or  min((NUM.NUM),(NUM.NUM)) or max(NUM.NUM,(NUM.NUM)) or  min(NUM.NUM,(NUM.NUM)) or max((NUM.NUM),(NUM.NUM))
        substrings_to_replace = regexp(str, to_replace, 'match');
        if isempty(substrings_to_replace)
            num_parenthesis = 0; %if num_parenthesis > 32 and there is nothing that can be replaced with regexp, we force this, in order to avoid an endless loop. Later, eval will catch an exception as it cannot evaluate when num_parenthesis>32
        else
            for j = 1:numel(substrings_to_replace)
                ss_rep = substrings_to_replace{j};
                str = strrep(str,ss_rep,num2str(eval(ss_rep),'%.15f'));
            end
            num_parenthesis = numel(strfind(str,')'));
       end
    end
    
    str = regexprep(str,'/','');
    
     try
        num_reaction_expression(i) = eval(str);   %evaluates the cells like they are numerical expressions (so as to compute min and max of gene expressions)
     catch
        warning('Problem using function.  Assigning a value of 1.');
        num_reaction_expression(i) = 1;
     end
end

for i=1:length(num_reaction_expression)   %loop over the array of the geneset expressions
    if num_reaction_expression(i)>=1
        fbamodel.lb(i) = fbamodel.lb(i)*(1+gamma*log(num_reaction_expression(i)));
        fbamodel.ub(i) = fbamodel.ub(i)*(1+gamma*log(num_reaction_expression(i)));
    else
        fbamodel.lb(i) = fbamodel.lb(i)/(1+gamma*abs(log(num_reaction_expression(i))));
        fbamodel.ub(i) = fbamodel.ub(i)/(1+gamma*abs(log(num_reaction_expression(i))));        
    end
end

if isfield(fbamodel, 'f')
    fbamodel.c = fbamodel.f;
end
sol_fba_minNorm = optimizeCbModel(fbamodel, 'max', 1e-6); %minNorm = 1e-6, minimizes overall sum of squared fluxes
v_out = sol_fba_minNorm.v;
format longG; format compact;
f_out = sol_fba_minNorm.f;
f_out
end