DROP TABLE users CASCADE;
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username varchar(64),
    email varchar(128),
    website varchar(128),
    avatar_file varchar(128)
);

ALTER TABLE users ADD column password character varying(128);
ALTER TABLE users ADD column openid_url character varying(256);

DROP TABLE groups;
CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name varchar(64)
);

DROP TABLE user_group;
CREATE TABLE user_group (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id),
    group_id integer NOT NULL REFERENCES groups(id)
);

DROP TABLE topics CASCADE;
CREATE TABLE topics (
    id SERIAL PRIMARY KEY,
    subject varchar(256),
    user_id integer NOT NULL REFERENCES users(id),
    views integer,
    parent_topic integer, -- for tree structure
    create_time integer
);

DROP TABLE posts;
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    text varchar(40960),
    topic_id integer NOT NULL REFERENCES topics(id),
    user_id integer NOT NULL REFERENCES users(id),
    comments integer,
    views integer,
    subject varchar(256),
    create_time integer
);
ALTER TABLE posts ADD column views integer;
ALTER TABLE posts ADD column comments integer;
ALTER TABLE posts ADD column subject character varying(512);

DROP TABLE comments;
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    text varchar(40960),
    user_id integer NOT NULL REFERENCES users(id),
    post_id integer NOT NULL REFERENCES posts(id),
    create_time integer
);

insert into users (id, username, email, website) values (1, 'tspenov', 'tspenov@datamax.bg', 'http://tspenov.com');

insert into groups (id, name) values (1, 'user');
insert into groups (id, name) values (2, 'admin');
insert into groups (id, name) values (3, 'moderator');

insert into user_group (id, user_id, group_id) values (1, 1, 1);
insert into user_group (id, user_id, group_id) values (2, 1, 2);
insert into user_group (id, user_id, group_id) values (3, 1, 3);

insert into topics (id, subject, user_id) values (1, 'Main Forum', 1);

