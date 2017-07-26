# 编码分类变量(Encoding Categorical Variables)

### 分类变量的编码系统  
在回归分析中，分类变量需要特别的关注,因为他们不同于二分法变量(dichotomous variables)和连续变量(continuous variables)，不能直接代入回归方程式。比如你有一个变量race，它的编码1=Hospanic,2=Asian,3=Black,4=White,在回归中输入race会得到race的线性作用，然而这可能不是你的目的。像这样的分类变量需要被记录到一系列的指标变量(indicator variables)中,然后才可以代入回归模型。这里有一系列编码系统（也被称作参照(contrasts)）能够被用来编码分类变量。包括虚拟编码(dummy coding),效果值编码(effect coding),正交编码(orthogonal coding)以及赫墨尔特编码(helmert coding)。
madlib当前仅支持虚拟编码技术。当一个分析人员想要比较其它组的预测变量和某一组指定的预测变量(predictor variable)时，可以用虚拟编码。通常，指定的那组被称作参考组。
```sql
create_indicator_variables(
    source_table,
    output_table,
    categorical_cols,
    keep_null,
    distributed_by
    )
```
#### 参数
  ##### source_table。
  VARCHAR。source_table表名，该表中包含了分类变量的数据。
  ##### output_table
  VARCHAR。结果表表名。结果表和原表有一些相同的列，对每一个分类列增加了一些新的指标变量列。指标变量列名类似于'categorical column name'\_'categorical value'。
  ##### categorical_cols
  VARCHAR.需要被应用虚拟编码的分类变量所在的列名组成的字符串，用逗号分隔。
  ##### keep_null (optional)
  BOOLEAN. 默认值FALSE。决定NULL是否要被当做分类变量中的一个类别。如果是TRUE，指标变量会被创建来表示NULL值。若果FALSE，该记录的所有指标变量会被设置为NULL。
  ##### distributed_by (optional)
  VARCHAR，默认NULL，输出表制定的用于分布的列。DANGWEINULL时，会应用source_table的分布策略。这个参数不能用于PostgreSQL平台上。

### 例子
1. 使用abalone数据集的子集
```sql
DROP TABLE IF EXISTS abalone;
CREATE TABLE abalone (
    sex character varying,
    length double precision,
    diameter double precision,
    height double precision
);
COPY abalone (sex, length, diameter, height) FROM stdin WITH DELIMITER '|' NULL as '@';
M| 0.455 |   0.365 | 0.095
F| 0.53  |   0.42  | 0.135
M| 0.35  |   0.265 | 0.09
F| 0.53  |   0.415 | 0.15
M| 0.44  |   0.365 | 0.125
F| 0.545 |   0.425 | 0.125
I| 0.33  |   0.255 | 0.08
F| 0.55  |   0.44  | 0.15
I| 0.425 |   0.30  | 0.095
F| 0.525 |   0.38  | 0.140
M| 0.475 |   0.37  | 0.125
F| 0.535 |   0.405 | 0.145
M| 0.43  |   0.358 | 0.11
F| 0.47  |   0.355 | 0.100
M| 0.49  |   0.38  | 0.135
F| 0.44  |   0.340 | 0.100
M| 0.5   |   0.400 | 0.13
F| 0.565 |   0.44  | 0.155
I| 0.355 |   0.280 | 0.085
F| 0.550 |   0.415 | 0.135
| 0.475 |   0.37  | 0.125
\.
```
2. 创建一个包含虚拟编码指标变量的新表
```sql
drop table if exists abalone_out;
select madlib.create_indicator_variables ('abalone', 'abalone_out', 'sex');
select * from abalone_out;
```
```
sex  | length | diameter | height | sex_F  | sex_I  | sex_M
 -----+--------+----------+--------+--------+--------+-------
F    |   0.53 |     0.42 |  0.135 |      1 |      0 |     0
F    |   0.53 |    0.415 |   0.15 |      1 |      0 |     0
F    |  0.545 |    0.425 |  0.125 |      1 |      0 |     0
F    |   0.55 |     0.44 |   0.15 |      1 |      0 |     0
F    |  0.525 |     0.38 |   0.14 |      1 |      0 |     0
F    |  0.535 |    0.405 |  0.145 |      1 |      0 |     0
F    |   0.47 |    0.355 |    0.1 |      1 |      0 |     0
F    |   0.44 |     0.34 |    0.1 |      1 |      0 |     0
F    |  0.565 |     0.44 |  0.155 |      1 |      0 |     0
F    |   0.55 |    0.415 |  0.135 |      1 |      0 |     0
M    |  0.455 |    0.365 |  0.095 |      0 |      0 |     1
M    |   0.35 |    0.265 |   0.09 |      0 |      0 |     0
M    |   0.44 |    0.365 |  0.125 |      0 |      0 |     0
I    |   0.33 |    0.255 |   0.08 |      0 |      1 |     0
I    |  0.425 |      0.3 |  0.095 |      0 |      1 |     0
M    |  0.475 |     0.37 |  0.125 |      0 |      0 |     0
M    |   0.43 |    0.358 |   0.11 |      0 |      0 |     0
M    |   0.49 |     0.38 |  0.135 |      0 |      0 |     0
M    |    0.5 |      0.4 |   0.13 |      0 |      0 |     0
I    |  0.355 |     0.28 |  0.085 |      0 |      1 |     0
NULL |   0.55 |    0.415 |  0.135 |   NULL |   NULL |  NULL
```
3. 为NULL值创建指标变量(注意额外的列"sex_NULL")
```sql
drop table if exists abalone_out;
select madlib.create_indicator_variables'abalone', 'abalone_out', 'sex', True);
select * from abalone_out;
```
```
sex  | length | diameter | height | sex_F  | sex_I  | sex_M | sex_NULL
 ---—+-----—+-------—+-----—+-----—+-----—+----—+----—
F    |   0.53 |     0.42 |  0.135 |      1 |      0 |     0 |     0
F    |   0.53 |    0.415 |   0.15 |      1 |      0 |     0 |     0
F    |  0.545 |    0.425 |  0.125 |      1 |      0 |     0 |     0
F    |   0.55 |     0.44 |   0.15 |      1 |      0 |     0 |     0
F    |  0.525 |     0.38 |   0.14 |      1 |      0 |     0 |     0
F    |  0.535 |    0.405 |  0.145 |      1 |      0 |     0 |     0
F    |   0.47 |    0.355 |    0.1 |      1 |      0 |     0 |     0
F    |   0.44 |     0.34 |    0.1 |      1 |      0 |     0 |     0
F    |  0.565 |     0.44 |  0.155 |      1 |      0 |     0 |     0
F    |   0.55 |    0.415 |  0.135 |      1 |      0 |     0 |     0
M    |  0.455 |    0.365 |  0.095 |      0 |      0 |     1 |     0
M    |   0.35 |    0.265 |   0.09 |      0 |      0 |     0 |     0
M    |   0.44 |    0.365 |  0.125 |      0 |      0 |     0 |     0
I    |   0.33 |    0.255 |   0.08 |      0 |      1 |     0 |     0
I    |  0.425 |      0.3 |  0.095 |      0 |      1 |     0 |     0
M    |  0.475 |     0.37 |  0.125 |      0 |      0 |     0 |     0
M    |   0.43 |    0.358 |   0.11 |      0 |      0 |     0 |     0
M    |   0.49 |     0.38 |  0.135 |      0 |      0 |     0 |     0
M    |    0.5 |      0.4 |   0.13 |      0 |      0 |     0 |     0
I    |  0.355 |     0.28 |  0.085 |      0 |      1 |     0 |     0
NULL |   0.55 |    0.415 |  0.135 |      0 |      0 |     0 |     1
```
