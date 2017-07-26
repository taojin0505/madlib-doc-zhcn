# Pivot

madlib Pivot函数的目的是提供一个数据汇聚工具能够在某张数据表上实现基本的OLAP类的操作，将汇总结果输出到另一张表中。
```sql
pivot(
    source_table,
    output_table,
    index,
    pivot_cols,
    pivot_values,
    aggregate_func,
    fill_value,
    keep_null,
    output_col_dictionary
    )
```
### 参数
  ##### source_table
  VARCHAR。需要将其中数据进行pivot的原表（视图）名。
  ##### output_table
  VARCHAR。含有pivot输出结果数据的表名。输出表含有所有出现在'index'列表中的列。对每一个distinct值额外增加了列'pivot_cols'.

    Note:
      输出表中的列名是自动生成的，具体请查看例子中是怎么实现的。惯例是使用以下字符串和分隔符下划线_来连接。
      * 值的列'pivot_values'的名称。
      * 聚合函数
      * pivot列'pivot_cols'的名称
      * pivotl列中的值
  ##### index
  VARCHAR，以逗号分隔的列，会形成输出pivot表的索引。通过index我们表明哪些值用来分组，它们是是pivot输出标的行。
  ##### pivot_cols
  VARCHAR，逗号分隔的列，会组成pivotl输出表的列
  ##### pivot_values
  VARCHAR.逗号分隔的列，包含了那些要被汇总的值
  ##### aggregate_func (optional)
  VARCHAR,默认值‘AVG’，逗号分隔将被应用于数据的聚合函数的列表。他们可以使PostgreSQL内置的aggregate或者用户自定义的aggregate.它能够对于每一个列值传递一系列aggregate。详情请请参考例子12-14。

      Note：
        这里只允许只有具有严格转换函数的aggregate。一个严格的转换函数意味着包含null的韩会被忽略；该函数不被调用并且之前的状态值被保留。如果你对null输入需要其他形式，它需要在pivot函数调用之前完成。包含严格转换函数的aggregate在[2,3]中介绍。
  ##### fill_value (optional)
  VARCHAR。默认NULL。如果被指定，将决定如何填充pivot操作结果的NULL值。这是一个全局参数(并不是应用于单个aggregate)，并且应用post-aggregation到输出表上。
  ##### keep_null (optional)
  BOOLEAN.默认值FALSE。如果是TRUE，会创建相当于NULL类别的pivot列。如果FALSE，对于NULL类别不会创建pivot列。
  ##### output_col_dictionary (optional)
  BOOLEAN。默认值FALSE。这个参数用来处理自动生成列名超过PostgreSQL限制的63byte(可能会经常发生).如果为TRUE，列名会被设置为数字类型ID并且会创建一个词典表，表名为output_table的值+\_dictionary后缀。如果是FALSE，会自动生成常规列名，除非超过了63byte限制。如果这样的话，会生成一个输出文件以及消息给用户。

  Note:
    * 在index列中的NULL会被当做和其它值一样对待
    * pivot列中的NULL会被忽略除非设置keep_null为TRUE
    * 只有严格转换函数被允许，所以NULL会被忽略
    * 不允许在设置fill_value 参数的时候而没有设置keep_null参数，以防止可能出现的不确定性。为默认方式设置aggregate_func为NULL并且按照需要使用fill_value.
    * 不允许在设置output_col_dictionary参数的时候而不设置keep_null参数以避免可能的不确定性。为默认方式设置keep_null为NULL并且按照需要使用output_col_dictionary.
    * 表达式(而不是列名)不被支持，为需要的表达式创建一个视图并且将其作为一个输入表(看例子3)
    * 对aggregate_func参数允许传递一个部分映射(partial mapping)。缺值的列会被按照默认函数（average）聚合

  ### 例子
  1. 创建一个简单的数据集来演示基础pivot.
  ```sql
  DROP TABLE IF EXISTS pivset CASCADE; -- View below may depend on table so use CASCADE
CREATE TABLE pivset(
                  id INTEGER,
                  piv INTEGER,
                  val FLOAT8
                );
INSERT INTO pivset VALUES
    (0, 10, 1),
    (0, 10, 2),
    (0, 20, 3),
    (1, 20, 4),
    (1, 30, 5),
    (1, 30, 6),
    (1, 10, 7),
    (NULL, 10, 8),
    (1, NULL, 9),
    (1, 10, NULL);
  ```
  2. 在这张表上执行pivot函数
  ```sql
  DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset', 'pivout', 'id', 'piv', 'val');
SELECT * FROM pivout ORDER BY id;
  ```
  ```
  id | val_avg_piv_10 | val_avg_piv_20 | val_avg_piv_30
----+----------------+----------------+----------------
 0 |            1.5 |              3 |
 1 |              7 |              4 |            5.5
   |              8 |                |
  ```
这里NULL在输出中会显示为空。
3. 现在我们增加更多的列到数据中并且创建一个视图。
```sql
DROP VIEW IF EXISTS pivset_ext;
CREATE VIEW pivset_ext AS
    SELECT *,
    COALESCE(id + (val / 3)::integer, 0) AS id2,
    COALESCE(100*(val / 3)::integer, 0) AS piv2,
    COALESCE(val + 10, 0) AS val2
   FROM pivset;
SELECT id,id2,piv,piv2,val,val2 FROM pivset_ext
ORDER BY id,id2,piv,piv2,val,val2;
```
```
id | id2 | piv | piv2 | val | val2
----+-----+-----+------+-----+------
 0 |   0 |  10 |    0 |   1 |   11
 0 |   1 |  10 |  100 |   2 |   12
 0 |   1 |  20 |  100 |   3 |   13
 1 |   0 |  10 |    0 |     |    0
 1 |   2 |  20 |  100 |   4 |   14
 1 |   3 |  10 |  200 |   7 |   17
 1 |   3 |  30 |  200 |   5 |   15
 1 |   3 |  30 |  200 |   6 |   16
 1 |   4 |     |  300 |   9 |   19
   |   0 |  10 |  300 |   8 |   18
(10 rows)
```
4. 我们使用另一个aggregate函数在刚才创建的视图上。
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val', 'sum');
SELECT * FROM pivout ORDER BY id;
```
```
id | val_sum_piv_10 | val_sum_piv_20 | val_sum_piv_30
----+----------------+----------------+----------------
 0 |              3 |              3 |
 1 |              7 |              4 |             11
   |              8 |                |
```
5. 现在创建一个自定义aggregate，注意这个aggregate必须有一个严格转换函数。
```sql
DROP FUNCTION IF EXISTS array_add1 (ANYARRAY, ANYELEMENT) CASCADE;
CREATE FUNCTION array_add1(ANYARRAY, ANYELEMENT) RETURNS ANYARRAY AS $$
  SELECT $1 || $2
$$ LANGUAGE sql STRICT;
DROP AGGREGATE IF EXISTS array_accum1 (anyelement);
CREATE AGGREGATE array_accum1 (anyelement) (
    sfunc = array_add1,
    stype = anyarray,
    initcond = '{}'                                                                                                                                           
);
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val', 'array_accum1');
SELECT * FROM pivout ORDER BY id;
```
```
id | val_array_accum1_piv_10 | val_array_accum1_piv_20 | val_array_accum1_piv_30
----+-------------------------+-------------------------+-------------------------
0 | {1,2}                   | {3}                     | {}
1 | {7}                     | {4}                     | {5,6}
  | {8}                     | {}                      | {}
```
6. 在pivot列中保持null值。
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val', 'sum', True);
SELECT * FROM pivout ORDER BY id;
```
```
id | val_sum_piv_10 | val_sum_piv_20 | val_sum_piv_30 | val_sum_piv_null
----+----------------+----------------+----------------+------------------
 0 |              3 |              3 |                |
 1 |              7 |              4 |             11 |                9
   |              8 |                |                |
```
7. 使用预设的值来填充null结果
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val', 'sum', '111');
SELECT * FROM pivout ORDER BY id;
```
```
id | val_sum_piv_10 | val_sum_piv_20 | val_sum_piv_30
----+----------------+----------------+----------------
 0 |              3 |              3 |            111
 1 |              7 |              4 |             11
   |              8 |            111 |            111
```
8. 使用多个index列。
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id,id2', 'piv', 'val');
SELECT * FROM pivout ORDER BY id,id2;
```
```
id | id2 | val_avg_piv_10 | val_avg_piv_20 | val_avg_piv_30
----+-----+----------------+----------------+----------------
 0 |   0 |              1 |                |
 0 |   1 |              2 |              3 |
 1 |   0 |                |                |
 1 |   2 |                |              4 |
 1 |   3 |              7 |                |            5.5
 1 |   4 |                |                |
   |   0 |              8 |                |
```
9. 打开可读的扩展视图
```sql
\x on
```
10. 使用多个pivot列
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv, piv2', 'val');
SELECT * FROM pivout ORDER BY id;
```
```
-[ RECORD 1 ]-----------+----
id                      | 0
val_avg_piv_10_piv2_0   | 1
val_avg_piv_10_piv2_100 | 2
val_avg_piv_10_piv2_200 |
val_avg_piv_10_piv2_300 |
val_avg_piv_20_piv2_0   |
val_avg_piv_20_piv2_100 | 3
val_avg_piv_20_piv2_200 |
val_avg_piv_20_piv2_300 |
val_avg_piv_30_piv2_0   |
val_avg_piv_30_piv2_100 |
val_avg_piv_30_piv2_200 |
val_avg_piv_30_piv2_300 |
-[ RECORD 2 ]-----------+----
id                      | 1
val_avg_piv_10_piv2_0   |
val_avg_piv_10_piv2_100 |
val_avg_piv_10_piv2_200 | 7
val_avg_piv_10_piv2_300 |
val_avg_piv_20_piv2_0   |
val_avg_piv_20_piv2_100 | 4
val_avg_piv_20_piv2_200 |
val_avg_piv_20_piv2_300 |
val_avg_piv_30_piv2_0   |
val_avg_piv_30_piv2_100 |
val_avg_piv_30_piv2_200 | 5.5
val_avg_piv_30_piv2_300 |
...
```
11. 使用多个value列
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val, val2');
SELECT * FROM pivout ORDER BY id;
```
```
-[ RECORD 1 ]---+-----
id              | 0
val_avg_piv_10  | 1.5
val_avg_piv_20  | 3
val_avg_piv_30  |
val2_avg_piv_10 | 11.5
val2_avg_piv_20 | 13
val2_avg_piv_30 |
-[ RECORD 2 ]---+-----
id              | 1
val_avg_piv_10  | 7
val_avg_piv_20  | 4
val_avg_piv_30  | 5.5
val2_avg_piv_10 | 8.5
val2_avg_piv_20 | 14
val2_avg_piv_30 | 15.5
...
```
12. 在一个value列上使用多个aggregate函数(矢量积)
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val', 'avg, sum');
SELECT * FROM pivout ORDER BY id;
```
```
-[ RECORD 1 ]--+----
id             | 0
val_avg_piv_10 | 1.5
val_avg_piv_20 | 3
val_avg_piv_30 |
val_sum_piv_10 | 3
val_sum_piv_20 | 3
val_sum_piv_30 |
-[ RECORD 2 ]--+----
id             | 1
val_avg_piv_10 | 7
val_avg_piv_20 | 4
val_avg_piv_30 | 5.5
val_sum_piv_10 | 7
val_sum_piv_20 | 4
val_sum_piv_30 | 11
...
```
13. 对于不同的value列使用不同的aggregate函数
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val, val2',
    'val=avg, val2=sum');
SELECT * FROM pivout ORDER BY id;
```
```
-[ RECORD 1 ]---+----
id              | 0
val_avg_piv_10  | 1.5
val_avg_piv_20  | 3
val_avg_piv_30  |
val2_sum_piv_10 | 23
val2_sum_piv_20 | 13
val2_sum_piv_30 |
-[ RECORD 2 ]---+----
id              | 1
val_avg_piv_10  | 7
val_avg_piv_20  | 4
val_avg_piv_30  | 5.5
val2_sum_piv_10 | 17
val2_sum_piv_20 | 14
val2_sum_piv_30 | 31
...
```
14. 对不同的value列使多个aggregate函数
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id', 'piv', 'val, val2',
    'val=avg, val2=[avg,sum]');
SELECT * FROM pivout ORDER BY id;
```
```
-[ RECORD 1 ]---+-----
id              | 0
val_avg_piv_10  | 1.5
val_avg_piv_20  | 3
val_avg_piv_30  |
val2_avg_piv_10 | 11.5
val2_avg_piv_20 | 13
val2_avg_piv_30 |
val2_sum_piv_10 | 23
val2_sum_piv_20 | 13
val2_sum_piv_30 |
-[ RECORD 2 ]---+-----
id              | 1
val_avg_piv_10  | 7
val_avg_piv_20  | 4
val_avg_piv_30  | 5.5
val2_avg_piv_10 | 8.5
val2_avg_piv_20 | 14
val2_avg_piv_30 | 15.5
val2_sum_piv_10 | 17
val2_sum_piv_20 | 14
val2_sum_piv_30 | 31
...
```
15. 合并所有选项
```sql
DROP TABLE IF EXISTS pivout;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id, id2', 'piv, piv2', 'val, val2',
    'val=avg, val2=[avg,sum]', '111', True);
SELECT * FROM pivout ORDER BY id,id2;
```
```
-[ RECORD 1 ]--------------+-----
id                         | 0
id2                        | 0
val_avg_piv_null_piv2_0    | 111
val_avg_piv_null_piv2_100  | 111
val_avg_piv_null_piv2_200  | 111
val_avg_piv_null_piv2_300  | 111
val_avg_piv_10_piv2_0      | 1
val_avg_piv_10_piv2_100    | 111
val_avg_piv_10_piv2_200    | 111
val_avg_piv_10_piv2_300    | 111
val_avg_piv_20_piv2_0      | 111
val_avg_piv_20_piv2_100    | 111
val_avg_piv_20_piv2_200    | 111
val_avg_piv_20_piv2_300    | 111
val_avg_piv_30_piv2_0      | 111
val_avg_piv_30_piv2_100    | 111
val_avg_piv_30_piv2_200    | 111
val_avg_piv_30_piv2_300    | 111
val2_avg_piv_null_piv2_0   | 111
val2_avg_piv_null_piv2_100 | 111
val2_avg_piv_null_piv2_200 | 111
val2_avg_piv_null_piv2_300 | 111
val2_avg_piv_10_piv2_0     | 11
val2_avg_piv_10_piv2_100   | 111
val2_avg_piv_10_piv2_200   | 111
val2_avg_piv_10_piv2_300   | 111
val2_avg_piv_20_piv2_0     | 111
val2_avg_piv_20_piv2_100   | 111
val2_avg_piv_20_piv2_200   | 111
val2_avg_piv_20_piv2_300   | 111
val2_avg_piv_30_piv2_0     | 111
val2_avg_piv_30_piv2_100   | 111
val2_avg_piv_30_piv2_200   | 111
val2_avg_piv_30_piv2_300   | 111
val2_sum_piv_null_piv2_0   | 111
val2_sum_piv_null_piv2_100 | 111
val2_sum_piv_null_piv2_200 | 111
val2_sum_piv_null_piv2_300 | 111
val2_sum_piv_10_piv2_0     | 11
val2_sum_piv_10_piv2_100   | 111
val2_sum_piv_10_piv2_200   | 111
val2_sum_piv_10_piv2_300   | 111
val2_sum_piv_20_piv2_0     | 111
val2_sum_piv_20_piv2_100   | 111
val2_sum_piv_20_piv2_200   | 111
val2_sum_piv_20_piv2_300   | 111
val2_sum_piv_30_piv2_0     | 111
val2_sum_piv_30_piv2_100   | 111
val2_sum_piv_30_piv2_200   | 111
val2_sum_piv_30_piv2_300   | 111
-[ RECORD 2 ]--------------+-----
id                         | 0
id2                        | 1
val_avg_piv_null_piv2_0    | 111
val_avg_piv_null_piv2_100  | 111
val_avg_piv_null_piv2_200  | 111
val_avg_piv_null_piv2_300  | 111
val_avg_piv_10_piv2_0      | 111
val_avg_piv_10_piv2_100    | 2
val_avg_piv_10_piv2_200    | 111
val_avg_piv_10_piv2_300    | 111
val_avg_piv_20_piv2_0      | 111
val_avg_piv_20_piv2_100    | 3
val_avg_piv_20_piv2_200    | 111
val_avg_piv_20_piv2_300    | 111
val_avg_piv_30_piv2_0      | 111
val_avg_piv_30_piv2_100    | 111
val_avg_piv_30_piv2_200    | 111
val_avg_piv_30_piv2_300    | 111
val2_avg_piv_null_piv2_0   | 111
val2_avg_piv_null_piv2_100 | 111
val2_avg_piv_null_piv2_200 | 111
val2_avg_piv_null_piv2_300 | 111
val2_avg_piv_10_piv2_0     | 111
val2_avg_piv_10_piv2_100   | 12
val2_avg_piv_10_piv2_200   | 111
val2_avg_piv_10_piv2_300   | 111
val2_avg_piv_20_piv2_0     | 111
val2_avg_piv_20_piv2_100   | 13
val2_avg_piv_20_piv2_200   | 111
val2_avg_piv_20_piv2_300   | 111
val2_avg_piv_30_piv2_0     | 111
val2_avg_piv_30_piv2_100   | 111
val2_avg_piv_30_piv2_200   | 111
val2_avg_piv_30_piv2_300   | 111
val2_sum_piv_null_piv2_0   | 111
val2_sum_piv_null_piv2_100 | 111
val2_sum_piv_null_piv2_200 | 111
val2_sum_piv_null_piv2_300 | 111
val2_sum_piv_10_piv2_0     | 111
val2_sum_piv_10_piv2_100   | 12
val2_sum_piv_10_piv2_200   | 111
val2_sum_piv_10_piv2_300   | 111
val2_sum_piv_20_piv2_0     | 111
val2_sum_piv_20_piv2_100   | 13
val2_sum_piv_20_piv2_200   | 111
val2_sum_piv_20_piv2_300   | 111
val2_sum_piv_30_piv2_0     | 111
val2_sum_piv_30_piv2_100   | 111
val2_sum_piv_30_piv2_200   | 111
val2_sum_piv_30_piv2_300   | 111
...
```
16. 为输出列名创建一个字典
```sql
DROP TABLE IF EXISTS pivout, pivout_dictionary;
SELECT madlib.pivot('pivset_ext', 'pivout', 'id, id2', 'piv, piv2', 'val, val2',
    'val=avg, val2=[avg,sum]', '111', True, True);
SELECT * FROM pivout_dictionary;
```
```
__pivot_cid__ | pval | agg | piv | piv2 |           col_name           
---------------+------+-----+-----+------+------------------------------
__p_1__       | val  | avg |     |  100 | "val_avg_piv_null_piv2_100"
__p_5__       | val  | avg |  10 |  100 | "val_avg_piv_10_piv2_100"
__p_9__       | val  | avg |  20 |  100 | "val_avg_piv_20_piv2_100"
__p_12__      | val  | avg |  30 |    0 | "val_avg_piv_30_piv2_0"
__p_16__      | val2 | avg |     |    0 | "val2_avg_piv_null_piv2_0"
__p_23__      | val2 | avg |  10 |  300 | "val2_avg_piv_10_piv2_300"
__p_27__      | val2 | avg |  20 |  300 | "val2_avg_piv_20_piv2_300"
__p_30__      | val2 | avg |  30 |  200 | "val2_avg_piv_30_piv2_200"
__p_34__      | val2 | sum |     |  200 | "val2_sum_piv_null_piv2_200"
__p_38__      | val2 | sum |  10 |  200 | "val2_sum_piv_10_piv2_200"
__p_41__      | val2 | sum |  20 |  100 | "val2_sum_piv_20_piv2_100"
__p_45__      | val2 | sum |  30 |  100 | "val2_sum_piv_30_piv2_100"
__p_2__       | val  | avg |     |  200 | "val_avg_piv_null_piv2_200"
__p_6__       | val  | avg |  10 |  200 | "val_avg_piv_10_piv2_200"
__p_11__      | val  | avg |  20 |  300 | "val_avg_piv_20_piv2_300"
__p_15__      | val  | avg |  30 |  300 | "val_avg_piv_30_piv2_300"
__p_19__      | val2 | avg |     |  300 | "val2_avg_piv_null_piv2_300"
__p_20__      | val2 | avg |  10 |    0 | "val2_avg_piv_10_piv2_0"
__p_24__      | val2 | avg |  20 |    0 | "val2_avg_piv_20_piv2_0"
__p_28__      | val2 | avg |  30 |    0 | "val2_avg_piv_30_piv2_0"
__p_33__      | val2 | sum |     |  100 | "val2_sum_piv_null_piv2_100"
__p_37__      | val2 | sum |  10 |  100 | "val2_sum_piv_10_piv2_100"
__p_42__      | val2 | sum |  20 |  200 | "val2_sum_piv_20_piv2_200"
__p_46__      | val2 | sum |  30 |  200 | "val2_sum_piv_30_piv2_200"
__p_3__       | val  | avg |     |  300 | "val_avg_piv_null_piv2_300"
__p_7__       | val  | avg |  10 |  300 | "val_avg_piv_10_piv2_300"
__p_10__      | val  | avg |  20 |  200 | "val_avg_piv_20_piv2_200"
__p_14__      | val  | avg |  30 |  200 | "val_avg_piv_30_piv2_200"
__p_18__      | val2 | avg |     |  200 | "val2_avg_piv_null_piv2_200"
__p_21__      | val2 | avg |  10 |  100 | "val2_avg_piv_10_piv2_100"
__p_25__      | val2 | avg |  20 |  100 | "val2_avg_piv_20_piv2_100"
__p_29__      | val2 | avg |  30 |  100 | "val2_avg_piv_30_piv2_100"
__p_32__      | val2 | sum |     |    0 | "val2_sum_piv_null_piv2_0"
__p_36__      | val2 | sum |  10 |    0 | "val2_sum_piv_10_piv2_0"
__p_43__      | val2 | sum |  20 |  300 | "val2_sum_piv_20_piv2_300"
__p_47__      | val2 | sum |  30 |  300 | "val2_sum_piv_30_piv2_300"
__p_0__       | val  | avg |     |    0 | "val_avg_piv_null_piv2_0"
__p_4__       | val  | avg |  10 |    0 | "val_avg_piv_10_piv2_0"
__p_8__       | val  | avg |  20 |    0 | "val_avg_piv_20_piv2_0"
__p_13__      | val  | avg |  30 |  100 | "val_avg_piv_30_piv2_100"
__p_17__      | val2 | avg |     |  100 | "val2_avg_piv_null_piv2_100"
__p_22__      | val2 | avg |  10 |  200 | "val2_avg_piv_10_piv2_200"
__p_26__      | val2 | avg |  20 |  200 | "val2_avg_piv_20_piv2_200"
__p_31__      | val2 | avg |  30 |  300 | "val2_avg_piv_30_piv2_300"
__p_35__      | val2 | sum |     |  300 | "val2_sum_piv_null_piv2_300"
__p_39__      | val2 | sum |  10 |  300 | "val2_sum_piv_10_piv2_300"
__p_40__      | val2 | sum |  20 |    0 | "val2_sum_piv_20_piv2_0"
__p_44__      | val2 | sum |  30 |    0 | "val2_sum_piv_30_piv2_0"
(48 rows)
```
```sql
SELECT * FROM pivout ORDER BY id,id2;
```
```
-[ RECORD 1 ]--
id       | 0
id2      | 0
__p_0__  | 111
__p_1__  | 111
__p_2__  | 111
__p_3__  | 111
__p_4__  | 1
__p_5__  | 111
__p_6__  | 111
__p_7__  | 111
__p_8__  | 111
__p_9__  | 111
__p_10__ | 111
__p_11__ | 111
__p_12__ | 111
__p_13__ | 111
__p_14__ | 111
__p_15__ | 111
__p_16__ | 111
__p_17__ | 111
__p_18__ | 111
__p_19__ | 111
__p_20__ | 11
__p_21__ | 111
__p_22__ | 111
__p_23__ | 111
__p_24__ | 111
__p_25__ | 111
__p_26__ | 111
__p_27__ | 111
__p_28__ | 111
__p_29__ | 111
__p_30__ | 111
__p_31__ | 111
__p_32__ | 111
__p_33__ | 111
__p_34__ | 111
__p_35__ | 111
__p_36__ | 11
__p_37__ | 111
__p_38__ | 111
__p_39__ | 111
__p_40__ | 111
__p_41__ | 111
__p_42__ | 111
__p_43__ | 111
__p_44__ | 111
__p_45__ | 111
__p_46__ | 111
__p_47__ | 111
-[ RECORD 2 ]--
id       | 0
id2      | 1
__p_0__  | 111
__p_1__  | 111
__p_2__  | 111
__p_3__  | 111
__p_4__  | 111
__p_5__  | 2
__p_6__  | 111
__p_7__  | 111
__p_8__  | 111
__p_9__  | 3
__p_10__ | 111
__p_11__ | 111
__p_12__ | 111
__p_13__ | 111
__p_14__ | 111
__p_15__ | 111
__p_16__ | 111
__p_17__ | 111
__p_18__ | 111
__p_19__ | 111
__p_20__ | 111
__p_21__ | 12
__p_22__ | 111
__p_23__ | 111
__p_24__ | 111
__p_25__ | 13
__p_26__ | 111
__p_27__ | 111
__p_28__ | 111
__p_29__ | 111
__p_30__ | 111
__p_31__ | 111
__p_32__ | 111
__p_33__ | 111
__p_34__ | 111
__p_35__ | 111
__p_36__ | 111
__p_37__ | 12
__p_38__ | 111
__p_39__ | 111
__p_40__ | 111
__p_41__ | 13
__p_42__ | 111
__p_43__ | 111
__p_44__ | 111
__p_45__ | 111
__p_46__ | 111
__p_47__ | 111
...
```
### 参考
[1][PostgreSQL 8.2 Aggregate Functions](https://www.postgresql.org/docs/8.2/static/functions-aggregate.html)
[2][PostgreSQL 8.2 CREATE AGGREGATE](https://www.postgresql.org/docs/8.2/static/sql-createaggregate.html)
[3][PostgreSQL 8.2 User-Defined Aggregates](https://www.postgresql.org/docs/8.2/static/xaggr.html)
