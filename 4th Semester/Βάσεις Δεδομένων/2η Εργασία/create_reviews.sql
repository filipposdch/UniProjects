create table "Reviews"(
   listing_id int,
   id int,
   date date,
   reviewer_id int,
   reviewer_name varchar(50),
   comments text,
   CONSTRAINT "Reviews_pk" PRIMARY KEY(id)
);