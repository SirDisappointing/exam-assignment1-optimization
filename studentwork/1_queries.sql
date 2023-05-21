--takes ~1.7 seconds(searching)
-- amount of lines = 19389
SELECT postid, id as comment_id, text
FROM comments
WHERE text ILIKE '%postgres%'
UNION
SELECT id, NULL AS comment_id, title AS text
FROM posts
WHERE title ILIKE '%postgres%' 
-- the body can be added as a filter like this (or body ILIKE '%postgres%')
order by postid


-- try creating a full_text_search index for the collumns I need to search through(this does take a while but afterwards any new entries to the database will be automatically indexed)
-- takes 42 seconds
-- Create a full-text search index on the 'text' column of the 'comments' table
CREATE INDEX idx_comments_text_search ON comments USING GIN(to_tsvector('english', text));


-- Create a full-text search index on the 'title' column of the 'posts' table
CREATE INDEX idx_posts_title_search ON posts USING GIN(to_tsvector('english', title));
CREATE INDEX idx_posts_body_search ON posts USING GIN(to_tsvector('english', body));


-- then try searching using the full_text_search
-- this takes ~0.084 second as opposed to ~1.7 seconds from the previous search
-- amount of entries = 7584 
-- due to the nature of a full text search, the search might exclude some entries based on some lingustics
SELECT postid, id AS comment_id, NULL AS title, text
FROM comments 
WHERE to_tsvector('english', text) @@ to_tsquery('english', 'postgres')
UNION
SELECT id AS postid, NULL AS comment_id, title, NULL AS text
FROM posts 
WHERE to_tsvector('english', title) @@ to_tsquery('english', 'postgres')
ORDER BY postid;

--to drop this index if you don't need it anymore
DROP INDEX idx_comments_text_search
DROP INDEX idx_posts_title_search;

-- in conclusion. full text search is technically the fastest way, but might exclude some entries unlike the substring search(ILIKE)



--takes 0.1 second(tags overview)
SELECT tags.tagname, COUNT(posttag.postid) AS usage_count FROM tags
LEFT JOIN posttag ON tags.id = posttag.tagid
GROUP BY tags.tagname
ORDER BY usage_count DESC


-- takes 1.087 seconds(user overview)
SELECT users.*, COUNT(DISTINCT posts.id) AS post_count FROM users
LEFT JOIN posts ON users.id = posts.owneruserid
GROUP BY users.id, users.displayname, users.websiteurl, users.location, users.aboutme, users.profileimageurl, users.creationdate;


-- takes 19.674 seconds
-- lines = 96126
SELECT
  posts.id AS question_id,
  LEFT(posts.body, 200) AS question_content,
  COUNT(DISTINCT comments.id) AS answer_count,
  ARRAY_AGG(DISTINCT tags.tagname) AS tags,
  posts.owneruserid AS author_username FROM posts
  JOIN users ON posts.owneruserid = users.id
  LEFT JOIN votes ON posts.id = votes.postid AND votes.votetypeid = 2
  LEFT JOIN comments ON posts.id = comments.postid
  LEFT JOIN posttag ON posts.id = posttag.postid
  LEFT JOIN tags ON posttag.tagid = tags.id
WHERE
  posts.posttypeid = 1
GROUP BY
  posts.id, posts.body, posts.owneruserid, posts.creationdate
ORDER BY
  posts.creationdate DESC;


-- depending on what question you pick it might take longer or shorter. but generally between 0.2 and 0.3 seconds
-- resulting entries also differ per question
SELECT c.postid AS post_id, c.id AS comment_id, c.text AS comment_content, u.displayname AS author_name
FROM comments c
JOIN users u ON c.userid = u.id
WHERE c.postid = (
  SELECT postid
  FROM comments
  ORDER BY random()
  LIMIT 1
)
ORDER BY c.postid;

-- this query selects all the posts and displays all comments and authors in order of postid
-- i am not sure what the interpretation was of the 5th query, but to find out I tried out both methods
-- time taken = ~0.6s
-- resulting entries = 328531
SELECT  c.postid, c.id AS comment_id, c.text AS comment_content, u.displayname AS author_name
FROM comments c
JOIN users u ON c.userid = u.id
WHERE c.postid IN (
  SELECT id
  FROM posts
)
ORDER BY c.postid;


-- 
