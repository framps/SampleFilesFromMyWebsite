-- Copyright (c) 2011, www.linux-tips-and-tricks.de

use VENNSQL;

-- (1) Inner join
-- Set: Intersection
-- SQL: Inner join
-- elements from TableA which have identical elements in TableB are selected
select * from TableA inner join TableB on TableA.name = TableB.name;

-- (2)Left outer join
-- Set: No equivalent
-- SQL: Left outer join
-- all elements from TableA are selected and elements which are in both TableA and TableB
select * from TableA left outer join TableB on TableA.name = TableB.name;

-- (3) Full outer join
-- Set: Union
-- SQL: Full outer join
-- all elements from TableA and TableB are selected and all duplicates are removed
-- because mysql doesn't offer a full outer join this is implemented as a union of
-- left and right join of the same tables
select * from TableA full join TableB on TableA.name = TableB.name;

-- (4) Cartesian product
-- Set: Cartesian product
-- SQL: Cartesian product
-- all elements from TableA are selected and combined
-- with all elements from TableB
select * from TableA,TableB;

-- (5) Left outer join minus inner join
-- Set: No equivalent
-- SQL: no mysql join
-- all elements from TableA are selected which don't exist in TableB
select * from TableA full join TableB on TableA.name = TableB.name
   WHERE TableB.id is null;

-- (6) Full outer join minus inner join
-- Set: Symmetric difference
-- SQL: no mysql join
-- all elements which are either in TableA or TableB but not in both tables are selected
select * from TableA full join TableB on TableA.name = TableB.name where TableB.id is null or TableA.id is null;

