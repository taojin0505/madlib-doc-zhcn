--文件下载http://grouplens.org/datasets/movielens/

--原始数据处理


create schema ml;

drop table if exists ml.ratings;
create table ml.ratings(
userId int,
movieId int,
rating decimal(2,1),
timestamp_epoch bigint);

copy ml.ratings from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/ratings.csv' CSV  HEADER;

alter table ml.ratings add column timestamp timestamp;
update ml.ratings  set timestamp=(timestamp with time zone 'epoch'+ timestamp_epoch * interval '1 second');

drop table if exists ml.tags;
create table ml.tags(
userId int,
movieId int,
tag varchar(1000),
timestamp_epoch bigint);

copy ml.tags from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/tags.csv' CSV  HEADER;
alter table ml.tags add column timestamp timestamp;
update ml.tags  set timestamp=(timestamp with time zone 'epoch'+ timestamp_epoch * interval '1 second');


drop table if exists ml.movies;
create table ml.movies(
movieId int,
title varchar(200),
genres varchar(2000)
);

copy ml.movies from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/movies.csv' CSV  HEADER;

drop table if exists ml.links;
create table ml.links(
movieId int,
imdbId int,
tmdbId int);

copy ml.links from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/links.csv' CSV  HEADER;


drop table if exists ml.genomescores;
create table ml.genomescores(
movieId int,
tagId int,
relevance decimal(20,18)
);

copy ml.genomescores from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/genome-scores.csv' CSV  HEADER;


drop table if exists ml.genometags;
create table ml.genometags(
tagId int,
tag varchar(1000)
);

copy ml.genometags from '/home/hadoop/document/madlib-doc-zhcn/ml-20m/genome-tags.csv' CSV  HEADER;


drop table if exists ml.ratings_100k;
create table ml.ratings_100k(
userId int,
movieId int,
rating decimal(2,1),
timestamp_epoch bigint);

copy ml.ratings_100k from '/home/hadoop/document/madlib-doc-zhcn/ml-100k/ratings.csv' CSV  HEADER;



--使用低秩矩阵分解


DROP TABLE IF EXISTS lmf_model;
SELECT madlib.lmf_igd_run( 'rating_100k_model',
                           'ml.ratings_100k',
                           'userid',
                           'movieid',
                           'rating',
                           671,
                           163943,
                           80,
                           0.001,
                           0.01,
                           50,
                           1e-9
                         );

--查看矩阵U的维数，可以看到是一个671 x 80的矩阵
select array_dims(matrix_u) from rating_100k_model limit 10;
  array_dims   
---------------
 [1:671][1:80]
(1 row)
--同样，查查看矩阵V的维数
select array_dims(matrix_v) from rating_100k_model limit 10;
    array_dims    
------------------
 [1:163943][1:80]

--使用U中某个userid的行向量和V中某个movieid的行向量计算点积dot product（scalar product标量积）
SELECT madlib.array_dot(matrix_u[2][1:80],matrix_v[3][1:80]) from rating_100k_model;

--验证参数：
SELECT madlib.lmf_igd_run( 'rating_100k_model',
                           'ml.ratings_100k',
                           'userid',
                           'movieid',
                           'rating',
                           671,
                           163943,
                           80,
                           0.001,
                           0.01,
                           50,
                           1e-9
                         );
--原值
select * from ml.ratings_100k where userid =10 and movieid=50;
 userid | movieid | rating | timestamp_epoch 
--------+---------+--------+-----------------
     10 |      50 |    5.0 |       942766420

select * from ml.ratings_100k where userid =10 and movieid=152;                               
 userid | movieid | rating | timestamp_epoch 
--------+---------+--------+-----------------
     10 |     152 |    4.0 |       942766793
--矩阵分解以后求值
SELECT madlib.array_dot(matrix_u[10:10][1:80],matrix_v[50:50][1:80]) from rating_100k_model;    
    array_dot     
------------------
 4.26344915212959


SELECT madlib.array_dot(matrix_u[10:10][1:80],matrix_v[152:152][1:80]) from rating_100k_model;    
    array_dot     
------------------
 2.82510572521788

--可以看到误差较大，调整参数以后重新计算：
SELECT madlib.lmf_igd_run( 'rating_100k_model',
                           'ml.ratings_100k',
                           'userid',
                           'movieid',
                           'rating',
                           671,
                           163943,
                           80,
                           0.02,
                           0.1,
                           20,
                           1e-4
                         );
--验证：
迭代次数       10:50            10:152
20        4.80298608737221    3.91850176865152  
30        5.01085358295014    3.9794137334562
40        4.82463277841873    3.99530988205385
50        4.85663323709284    3.99816106985449
100       5.01410883182546    3.99940992722881

--增加输出矩阵的秩
SELECT madlib.lmf_igd_run( 'rating_100k_model',
                           'ml.ratings_100k',
                           'userid',
                           'movieid',
                           'rating',
                           671,
                           163943,
                           100,
                           0.02,
                           0.1,
                           30,
                           1e-4
                         );
--验证：
输出矩阵的秩    10:50                 10:152                50:21                 70:9
原值         5                     4                     3                     3
60          4.55269723801434      3.97983919583706      3.52089003599823      3.05189296628744
80          5.01085358295014      3.9794137334562       3.22039779929768      3.0177912672334
100         4.82460713528099      3.99706904066475      3.11632817340702      3.05463950340992
120         4.69284014691578      3.9744186536897       2.93720749008402      3.13482060853382

--userid和movieid不连续的话，分解矩阵也会模拟出不存在记录的记过

--以下使用ml-100k为例，查看记录
--movieid不连续，所以整理了一下，避免再后面生成太多不必要的数据
alter table ml.ratings_100k add column mlid int;
create table ml.ratings100kid(movieid int,mlid int);
create table ml.ratings100kid2(movieid int,mlid int);
insert into ml.ratings100kid select distinct movieid from ml.ratings_100k;
insert into ml.ratings100kid2  select movieid,rank() over(order by movieid) from ml.ratings100kid；
update ml.ratings_100k t set mlid=(select mlid from ml.ratings100kid2 s where t.movieid=s.movieid);


SELECT madlib.lmf_igd_run( 'rating_100k_model',
                           'ml.ratings_100k',
                           'userid',
                           'mlid',
                           'rating',
                           671,
                           9066,
                           80,
                           0.02,
                           0.1,
                           30,
                           1e-4
                         );
                         
SELECT madlib.array_dot(matrix_u[10:10][1:80],matrix_v[311:311][1:80]) from rating_100k_model;
    array_dot     
------------------
 3.95211515441752
select * from ml.ratings_100k where userid=10 and mlid=311;                                   
 userid | movieid | rating | timestamp_epoch | mlid 
--------+---------+--------+-----------------+------
     10 |     345 |    4.0 |       942766603 |  311

--还原矩阵
--创建稀疏矩阵（为了方便数据处理和sql执行，格式和原矩阵类似）
create table ratings100kml(useid int,mlid int,rating float8);
SELECT array_length(matrix_u) from rating_100k_model;
SELECT madlib.array_dot(matrix_u[10:10][1:80],matrix_v[311:311][1:80]) from rating_100k_model;

CREATE OR REPLACE FUNCTION get_rating(rownum int,colnum int,rank int,tbname text) RETURNS void
AS $$
DECLARE
  rowid int8 := 1;
  colid int8 := 1;
  x float8;
BEGIN
  WHILE rowid <= rownum
  LOOP
    raise notice 'calculate row % ',rowid;
    colid := 1;
    WHILE colid <= colnum
    LOOP
      execute 'SELECT madlib.array_dot(matrix_u['||rowid||':'||rowid||'][1:'||rank||'],matrix_v['||colid||':'||colid||'][1:'||rank||']) from '||tbname::regclass||';' into x;
      --raise notice 'value row % ,col %  rating %',rowid,colid,x;
      insert into ratings100kml values(rowid,colid,x);
      colid := colid + 1;
    END LOOP;
    
    rowid:=rowid+1;
    
  END LOOP;
  RETURN;
END;
$$ LANGUAGE plpgsql;

--展示出某个用户评分前10的电影
select t.useid,t.rating,s.title,s.genres from ratings100kml t ,ml.ratings100kid2 r,ml.movies s where t.mlid=r.mlid and r.movieid=s.movieid and  t.useid=1  order by rating desc limit 10;
 useid |      rating      |                           title                            |             genres             
 
-------+------------------+------------------------------------------------------------+--------------------------------
-
     1 | 3.90578075686691 | Braveheart (1995)                                          | Action|Drama|War
     1 | 3.88593435780966 | Cinema Paradiso (Nuovo cinema Paradiso) (1989)             | Drama
     1 | 3.87207228386002 | Dracula (Bram Stoker's Dracula) (1992)                     | Fantasy|Horror|Romance|Thriller
     1 | 3.82464143998219 | Prime of Miss Jean Brodie, The (1969)                      | Drama
     1 |  3.8060989867013 | Philomena (2013)                                           | Comedy|Drama
     1 | 3.79989898287122 | Usual Suspects, The (1995)                                 | Crime|Mystery|Thriller
     1 | 3.77379718336724 | Maya Lin: A Strong Clear Vision (1994)                     | Documentary
     1 | 3.75268047046594 | Hachiko: A Dog's Story (a.k.a. Hachi: A Dog's Tale) (2009) | Drama
     1 | 3.73962711376253 | 40-Year-Old Virgin, The (2005)                             | Comedy|Romance
     1 | 3.73465800081345 | Almost Famous (2000)                                       | Drama

和用户自己投票的对比
select round(u.rating::numeric,1) as rating,coalesce(v.rating,0) as voterating,u.movieid,u.title,u.genres
from
(select t.useid,t.rating,s.movieid,s.title,s.genres from ratings100kml t ,ml.ratings100kid2 r,ml.movies s where t.mlid=r.mlid and r.movieid=s.movieid and  t.useid=1  order by rating desc limit 10) u left join ml.ratings_100k v
on u.useid=v.userid  
and u.movieid=v.movieid
order by u.rating desc;
 rating | voterating | movieid |                           title                            |             genres        
      
--------+------------+---------+------------------------------------------------------------+---------------------------
------
    3.9 |          0 |     110 | Braveheart (1995)                                          | Action|Drama|War
    3.9 |        4.0 |    1172 | Cinema Paradiso (Nuovo cinema Paradiso) (1989)             | Drama
    3.9 |        3.5 |    1339 | Dracula (Bram Stoker's Dracula) (1992)                     | Fantasy|Horror|Romance|Thr
iller
    3.8 |          0 |    8754 | Prime of Miss Jean Brodie, The (1969)                      | Drama
    3.8 |          0 |  106438 | Philomena (2013)                                           | Comedy|Drama
    3.8 |          0 |      50 | Usual Suspects, The (1995)                                 | Crime|Mystery|Thriller
    3.8 |          0 |     759 | Maya Lin: A Strong Clear Vision (1994)                     | Documentary
    3.8 |          0 |   73290 | Hachiko: A Dog's Story (a.k.a. Hachi: A Dog's Tale) (2009) | Drama
    3.7 |          0 |   35836 | 40-Year-Old Virgin, The (2005)                             | Comedy|Romance
    3.7 |          0 |    3897 | Almost Famous (2000)                                       | Drama

--求出电影的相似度

  --将稀疏评分矩阵转换成以movieid为rowid的密集矩阵，计算每个movie上评分向量之间的夹角来计算相似度
  SELECT madlib.matrix_densify('ratings100kml', 'row="mlid", col=useid, val=rating',
                              'ratings100kml_movie');
  --查看生成的矩阵
  select madlib.matrix_ndims('ratings100kml_movie','row=mlid, val=rating');
   matrix_ndims 
  --------------
   {9066,671}
  --计算电影的相似度
  生成某个电影和其它电影的相似度
select t.mlid,s.mlid,madlib.cosine_similarity(t.rating,s.rating) as sim           
  from ratings100kml_movie t,ratings100kml_movie s  
  where t.mlid=1
  order by sim desc;
 mlid | mlid |        sim        
------+------+-------------------
    1 |    1 |                 1
    1 |  383 | 0.985292539355888
    1 | 1017 | 0.985263098800495
    1 |  296 |  0.98519836681063
    1 | 8586 |   0.9849806056546
    1 | 1449 |  0.98487853946488
    1 | 7824 | 0.984856985844692
    1 | 3838 | 0.984712658285672
    1 |  634 |  0.98463748961411
    1 | 5916 | 0.984604275760795
    1 | 2212 | 0.984554185842966
    1 | 8383 | 0.984544312475862
  
--求出用户的相似度
  --将稀疏评分矩阵转换成以userid为rowid的密集矩阵，计算每个user上评分向量之间的夹角来计算相似度
  SELECT madlib.matrix_densify('ratings100kml', 'row="useid", col=mlid, val=rating',
                              'ratings100kml_user');
  --查看生成的矩阵
  select madlib.matrix_ndims('ratings100kml_user','row=useid, val=rating');
   matrix_ndims 
   --------------
    {671,9066}

  --计算电影的相似度
  --生成某个用户和其它用户的相似度
select t.useid,s.useid,madlib.cosine_similarity(t.rating,s.rating) as sim
  from ratings100kml_user t,ratings100kml_user s
  where t.useid=1
  order by sim desc;
 useid | useid |        sim        
-------+-------+-------------------
     1 |     1 |                 1
     1 |   113 | 0.998110317051059
     1 |   435 | 0.997871834146785
     1 |   443 | 0.997836342109379
     1 |   104 | 0.997802463248035
     1 |   663 | 0.997756450967415
     1 |   566 | 0.997748137742039
     1 |   298 | 0.997746204777706
     1 |   246 | 0.997735088088766
     1 |   446 | 0.997726995473673
  

     
--使用SVD
因为原始数据是稀疏矩阵，所以直接使用稀疏矩阵计算
drop table if exists rating_100k_svd_u;
drop table if exists rating_100k_svd_s;
drop table if exists rating_100k_svd_v;
SELECT madlib.svd_sparse( 'ml.ratings_100k',
                          'rating_100k_svd',
                          'userid', 
                          'movieid', 
                          'rating', 
                          671,
                          163943,    
                          40,
                          40
                          );


--非常稀疏矩阵
SELECT madlib.svd_sparse_native ( 'ml.ratings_100k',   -- Input table
                          'rating_100k_svd_spares',          -- Output table prefix
                          'userid',       -- Column name with row index 
                          'movieid',       -- Column name with column index 
                          'rating',        -- Matrix cell value
                          671,             -- Number of rows in matrix
                          163943,             -- Number of columns in matrix    
                          80              -- Number of singular values to compute
                          );

SELECT madlib.svd_sparse_native ( 'ml.ratings_100k',
                          'rating_100k_svd_spares',
                          'userid',
                          'movieid', 
                          'rating', 
                          671,      
                          163943,      
                          80,
                          20
                          );
                          
--转换到密集矩阵
--用userid作为rowid的话，因为movie比较多,会导致矩阵很宽
SELECT madlib.matrix_densify('ml.ratings_100k', 'row="userid", col=movieid, val=rating',
                             'ml.ratings_100k_dense');
SELECT madlib.svd( 'ml.ratings_100k_dense',
                   'svd_ratings_100k_dense',
                   'userid', 
                   20,
                   20,
                   'ratings_100k_svd_summary_table'
                 );
                 
--对20m的数据进行计算 内存溢出（机器内存16G，使用内存和数据库share_mem无关）
--转换到密集矩阵
--用userid作为rowid的话，因为movie比较多,会导致矩阵很宽
drop table if exists rating_svd_u;
drop table if exists rating_svd_s;
drop table if exists rating_svd_v;
SELECT madlib.svd_sparse( 'ml.ratings',
                          'rating_svd',
                          'userid', 
                          'movieid', 
                          'rating', 
                          671,
                          163943,    
                          20,
                          30
                          );
                          
--还原使用madlib.svd_sparse计算的矩阵                 
drop table if exists rating_100k_svd_s_dense;
SELECT madlib.matrix_densify('rating_100k_svd_s', 'row="row_id", col=col_id, val=value',
                             'rating_100k_svd_s_dense');
drop table if exists rating_100k_svd_us;
SELECT madlib.matrix_mult('rating_100k_svd_u', 'row=row_id, val=row_vec',
                           'rating_100k_svd_s_dense', 'row=row_id, val=value',
                           'rating_100k_svd_us');
drop table if exists  rating_100k_svd_usv;
SELECT madlib.matrix_mult('rating_100k_svd_us', 'row=row_id, val=row_vec',
                           'rating_100k_svd_v', 'row=row_id, val=row_vec, trans=true',
                           'rating_100k_svd_usv');

--还原使用madlib.svd计算的矩阵                           
SELECT madlib.matrix_densify('svd_ratings_100k_dense_s', 'row="row_id", col=col_id, val=value',
                             'svd_ratings_100k_dense_s_dense');

SELECT madlib.matrix_mult('svd_ratings_100k_dense_u', 'row=row_id, val=row_vec',
                           'svd_ratings_100k_dense_s_dense', 'row=row_id, val=value',
                           'svd_ratings_100k_dense_us');

SELECT madlib.matrix_mult('svd_ratings_100k_dense_us', 'row=row_id, val=row_vec',
                           'svd_ratings_100k_dense_v', 'row=row_id, val=row_vec, trans=true',
                           'svd_ratings_100k_dense_usv');

--还原使用madlib.svd_sparse_native计算的矩阵
SELECT madlib.matrix_densify('rating_100k_svd_spares_s', 'row="row_id", col=col_id, val=value',
                             'rating_100k_svd_spares_s_dense');

SELECT madlib.matrix_mult('rating_100k_svd_spares_u', 'row=row_id, val=row_vec',
                           'rating_100k_svd_spares_s_dense', 'row=row_id, val=value',
                           'rating_100k_svd_spares_us');

SELECT madlib.matrix_mult('rating_100k_svd_spares_us', 'row=row_id, val=row_vec',
                           'rating_100k_svd_spares_v', 'row=row_id, val=row_vec, trans=true',
                           'rating_100k_svd_spares_usv');
--结果校验 貌似不太准确
select * from ml.ratings_100k where userid=50 and movieid=150;
select row_vec[150:150] from rating_100k_svd_usv where row_id=50;
select row_vec[150:150] from svd_ratings_100k_dense_usv where row_id=50;
select row_vec[150:150] from rating_100k_svd_spares_usv where row_id=50;

select row_vec[50:50] from rating_100k_svd_usv where row_id=16;
select row_vec[318:318] from rating_100k_svd_usv where row_id=16;
select row_vec[150:150] from rating_100k_svd_usv where row_id=50;


数据位置   奇异值   原值     rating_100k_svd_usv    svd_ratings_100k_dense_usv    rating_100k_svd_spares_usv
50:150    20      3       2.4894461380709        2.78654153159787               2.80991921980527
16:318    20      4       0.912745009311378      1.15768510020784               1.35123989005834
16:50     20      4.5     0.513817954077285      0.615334862645116              0.772066988504176
16:50     10      4.5     0.694826145457832
50:150    10      3       2.32276884633272
16:318    10      3       0.895463565622592
16:50     30      4.5     0.770055443715891
50:150    30      3       2.987055794216
16:318    30      3       1.25924560302146
16:50     40      4.5     1.06427263189391
50:150    40      3       3.15245483066303
16:318    40      3       1.51737327160129

--单独计算某个用户的评分
select * from ml.ratings_100k where userid=251 and movieid=1196;

create table svd_ratings_100k_dense_u_251 as select * from svd_ratings_100k_dense_u where row_id=251;

update svd_ratings_100k_dense_u_251 set row_id=1;

SELECT madlib.matrix_mult('svd_ratings_100k_dense_u_251', 'row=row_id, val=row_vec',
                           'svd_ratings_100k_dense_s_dense', 'row=row_id, val=value',
                           'svd_ratings_100k_dense_us_251');

SELECT madlib.matrix_mult('svd_ratings_100k_dense_us_251', 'row=row_id, val=row_vec',
                           'svd_ratings_100k_dense_v', 'row=row_id, val=row_vec,trans=true',
                           'svd_ratings_100k_dense_usv_251');

SELECT madlib.matrix_sparsify('svd_ratings_100k_dense_usv_251', 'row=row_id, val=row_vec',
                               'svd_ratings_100k_dense_usv_251_spars', 'col=col_id, val=val');

update svd_ratings_100k_dense_usv_251_spars set val=round(val::numeric,1);


--图像分解还原：
create table matrp(row_id int,value float8[]);
insert into matrp values(1,'{0,0,0,0,0,0,0,0,0,0}');
insert into matrp values(2,'{0,1,1,0,0,0,0,1,1,0}');
insert into matrp values(3,'{0,1,1,0,0,0,1,1,0,0}');
insert into matrp values(4,'{0,0,1,1,0,1,1,0,0,0}');
insert into matrp values(5,'{0,0,0,1,1,1,0,0,0,0}');
insert into matrp values(6,'{0,0,0,0,1,1,0,0,0,0}');
insert into matrp values(7,'{0,1,1,1,1,1,1,0,0,0}');
insert into matrp values(8,'{0,1,1,1,1,1,1,1,0,0}');
insert into matrp values(9,'{0,0,0,0,0,0,0,0,0,0}');

SELECT madlib.matrix_mult('matrp', 'row=row_id, val=value, trans=true',
                          'matrp', 'row=row_id, val=value',
                          'matrp_mult');
--求特征值，来评估奇异值个数
SELECT madlib.matrix_eigen('matrp_mult', 'row=row_id, val=value','matrp_mult_eigen');

SELECT madlib.svd( 'matrp',
                   'svd_matrp',
                   'row_id', 
                   4,
                   4,
                   'matrp_svd_summary_table'
                 );

SELECT madlib.matrix_densify('svd_matrp_s', 'row="row_id", col=col_id, val=value',
                             'svd_matrp_s_dense');

SELECT madlib.matrix_mult('svd_matrp_u', 'row=row_id, val=row_vec',
                           'svd_matrp_s_dense', 'row=row_id, val=value',
                           'svd_matrp_us');

SELECT madlib.matrix_mult('svd_matrp_us', 'row=row_id, val=row_vec',
                           'svd_matrp_v', 'row=row_id, val=row_vec, trans=true',
                           'svd_matrp_usv');

结果：
select value from matrp order by row_id;
         value         
-----------------------
 {0,0,0,0,0,0,0,0,0,0}
 {0,1,1,0,0,0,0,1,1,0}
 {0,1,1,0,0,0,1,1,0,0}
 {0,0,1,1,0,1,1,0,0,0}
 {0,0,0,1,1,1,0,0,0,0}
 {0,0,0,0,1,1,0,0,0,0}
 {0,1,1,1,1,1,1,0,0,0}
 {0,1,1,1,1,1,1,1,0,0}
 {0,0,0,0,0,0,0,0,0,0}
select row_vec::int[] from svd_matrp_usv order by row_id;
        row_vec        
-----------------------
 {0,0,0,0,0,0,0,0,0,0}
 {0,1,1,0,0,0,0,1,1,0}
 {0,1,1,0,0,0,1,1,0,0}
 {0,0,1,1,0,1,1,0,0,0}
 {0,0,0,1,1,1,0,0,0,0}
 {0,0,0,0,1,1,0,0,0,0}
 {0,1,1,1,1,1,1,0,0,0}
 {0,1,1,1,1,1,1,1,0,0}
 {0,0,0,0,0,0,0,0,0,0}