#Principal component projection  

Principal component projection是一个将高维度数据映射到低维度空间的数学过程。低维度空间被定义为在训练数据中有最高误差的k principal component（原文： This lower dimensional space is defined by the k principal components with the highest variance in the training data）。更详细的PCA有关数据计算能够在![pca_train](http://madlib.incubator.apache.org/docs/latest/pca_8sql__in.html#a31abf88e67a446a4f789764aa2c61e85)能够看到，一些关于principal component projection的计算能够在![技术背景](http://madlib.incubator.apache.org/docs/latest/group__grp__mlogreg.html#background)中找到。  

##映射函数  
映射函数具有以下形式：  
>     madlib.pca_project( source_table,
                    pc_table,
                    out_table,
                    row_id,
                    residual_table,
                    result_summary_table
                  )  

和  
>     madlib.pca_sparse_project( source_table,
                           pc_table,
                           out_table,
                           row_id,
                           col_id,
                           val_id,
                           row_dim,
                           col_dim,
                           residual_table,
                           result_summary_table
                         )  

##参数：  
source_table：  
TEXT.源表名。等同于![pca_train](http://madlib.incubator.apache.org/docs/latest/pca_8sql__in.html#a31abf88e67a446a4f789764aa2c61e85),输入的数据矩阵必须有N行和M列，N是数据点数，M每个数据点的特征数量。  
pca_project的输入表必须为两种基本的madlib密集矩阵格式中的一种，pca_sparse_project的稀疏输入表必须为基本的madlib的稀疏矩阵格式。这些格式在![pca_train](http://madlib.incubator.apache.org/docs/latest/pca_8sql__in.html#a31abf88e67a446a4f789764aa2c61e85)中有所描述。  
pc_table：  
TEXT.包含principal component的表名  
out_table：  
TEXT.低维度形式表示的输入数据的表名  
out_table将一个密集矩阵解码映射到principal component。该表有以下列：  
row_id 输出矩阵的row_id
row_vec 包含矩阵的行的element的向量  
row_id：  
TEXT.包含输入数据表row IDs的列名。列的类型必须为能够cast刀INT的类型，并且包含1到N的值。对于密集矩阵格式，它必须包含从1到N的连续整数。  
col_id：  
TEXT.包含稀疏矩阵形式（只能为稀疏矩阵）输入数据表col IDs的列名。列的类型必须为能够被cast到INT的类型，包含的值为1到M。  
val_id：  
TEXT.稀疏矩阵形式中的val_id。  
row_dim：  
INTEGER,稀疏矩阵的行数。  
col_dim：  
INTEGER,稀疏矩阵的列数。
residual_table (optional)：  
TEXT,默认为NULL。可选的残差表名。(Name of the optional residual table.)  
residual_table解码一个密集残差矩阵，该表有以下列：  
row_id：输出矩阵的行数
row_vec：包含残差矩阵每行的element的向量。  
result_summary_table (optional)：   
TEXT,默认值是NULL，汇总表的名称。
result_summary_table包含PCA映射的运行时间信息。该表有以下列：  
exec_time 函数的运行时间（ms）  
residual_norm 残值的绝对误差。  
relative_residual_norm 残值的相对误差。  

##例子  
1. 查看PCA映射函数的在线帮助。  
> SELECT madlib.pca_project();  

2.创建示例数据。  
>     DROP TABLE IF EXISTS mat;
    CREATE TABLE mat (
    row_id integer,
    row_vec double precision[]
    );
    INSERT INTO mat VALUES
    (1, ARRAY[4,7,5]),
    (2, ARRAY[1,2,5]),
    (3, ARRAY[7,4,4]),
    (4, ARRAY[9,2,4]),
    (5, ARRAY[8,5,7]),
    (6, ARRAY[0,5,5]);  
3. 运行PCA函数保留top2 principal component。  
>        DROP TABLE IF EXISTS result_table;
       SELECT pca_train ( 'mat',
                   'result_table',
                   'row_id',
                   2
                 );    
4. 将原始数据映射到低维度形式。  
>        DROP TABLE IF EXISTS residual_table,result_summary_table, out_table;
       SELECT pca_project( 'mat',
                    'result_table',
                    'out_table'
                    'row_id',
                    'residual_table',
                    'result_summary_table'
                  );  
5. 检查映射的误差  
>        SELECT * FROM result_summary_table;  
结果：  
>            exec_time   | residual_norm | relative_residual_norm
       ---------------+---------------+------------------------
         5685.40501595 | 2.19726255664 |         0.099262204234  
##注意  
* 函数将用于pca_train或者pca_sparse_train生成的principal component表的操作。madlib PCA函数生成一张包含‘column-mean’表以及一张包含principal component的表。(The MADlib PCA functions generate a table containing the column-means in addition to a table containing the principal components.)如果该表没有被MADlib映射函数找到，它会触发一个error。只要madlib函数生成了principal component，‘column-mean’表会自动被madlib映射函数找到。
* 因为PCA映射的中间步骤（具体请查看“”技术背景”），稀疏矩阵几乎总会在映射过程中变成密集矩阵。因此，稀疏矩阵输入会自动实现密集化，使用稀疏矩阵输入替代密集矩阵输入没有性能改善。
* 表名能够可选的被schema限定（如果shemale name没有指定，默认查询current_schemas()）。所有的表名和列名必须遵循大小写敏感以及引号规则。（例如，‘mytable’和‘MyTable’会被指向相同对象，等价与‘mytable’。如果对象名称使用混合大小写或者多字节字符，字符串必须用双引号引起来，在这个例子中输入必须为“MyTable”)  

##技术背景  
给一个表包含一些principal component P和一些输入数据 X，低维度形式的![](http://madlib.incubator.apache.org/docs/latest/form_231.png)计算公式为：![](http://madlib.incubator.apache.org/docs/latest/form_232.png).其中![](http://madlib.incubator.apache.org/docs/latest/form_233.png)是X的column mean。![](http://madlib.incubator.apache.org/docs/latest/form_225.png)是值全为1的向量。这个步骤等价与将原始数据集中。(his step is equivalent to centering the data around the origin.)  
残差表R是一个低维度形式有多么近似于真实输入数据的度量，通过![](http://madlib.incubator.apache.org/docs/latest/form_235.png)计算。  
一个残值矩阵保函的非常近似于0的entity表明一种好的表示形式。  
残值范数 r 比较简单：![](http://madlib.incubator.apache.org/docs/latest/form_237.png).其中![](http://madlib.incubator.apache.org/docs/latest/form_238.png)是Frobenius范数。相对残值范数![](http://madlib.incubator.apache.org/docs/latest/form_239.png)是：![](http://madlib.incubator.apache.org/docs/latest/form_240.png).  

##相关主题  
文件![pca_project_sql](http://madlib.incubator.apache.org/docs/latest/pca__project_8sql__in.html)是sql函数的文档。  
![Principal Component Analysis](http://madlib.incubator.apache.org/docs/latest/group__grp__pca__train.html)
