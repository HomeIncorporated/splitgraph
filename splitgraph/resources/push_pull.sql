-- API functions to access various parts of splitgraph_meta related to downloading and uploading images.
-- Serves as a level of indirection between Splitgraph push/pull logic and the organisation of the actual
-- SQL tables.

DROP SCHEMA IF EXISTS splitgraph_api CASCADE;
CREATE SCHEMA splitgraph_api;


---
-- IMAGE API
---

-- get_images(namespace, repository): get metadata for an image
CREATE OR REPLACE FUNCTION splitgraph_api.get_images(_namespace varchar, _repository varchar)
  RETURNS TABLE (
    image_hash      VARCHAR,
    parent_id       VARCHAR,
    created         TIMESTAMP,
    comment         VARCHAR,
    provenance_type VARCHAR,
    provenance_data JSONB) AS $$
BEGIN
   RETURN QUERY
   SELECT i.image_hash, i.parent_id, i.created, i.comment, i.provenance_type, i.provenance_data
   FROM splitgraph_meta.images i
   WHERE i.namespace = _namespace and i.repository = _repository
   ORDER BY created ASC;
END
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- get_tagged_images(namespace, repository): get hashes of all images with a tag.
CREATE OR REPLACE FUNCTION splitgraph_api.get_tagged_images(_namespace varchar, _repository varchar)
  RETURNS TABLE (
    image_hash VARCHAR,
    tag        VARCHAR) AS $$
BEGIN
   RETURN QUERY
   SELECT t.image_hash, t.tag
   FROM splitgraph_meta.tags t
   WHERE t.namespace = _namespace and t.repository = _repository;
END
$$ LANGUAGE plpgsql SECURITY INVOKER;


--
-- OBJECT API
--

-- get_object_path(object_ids): list all objects that object_ids depend on, recursively
CREATE OR REPLACE FUNCTION splitgraph_api.get_object_path(object_ids varchar[]) RETURNS varchar[] AS $$
BEGIN
    RETURN ARRAY(WITH RECURSIVE parents AS
        (SELECT object_id, parent_id FROM splitgraph_meta.objects WHERE object_id = ANY(object_ids)
            UNION ALL SELECT o.object_id, o.parent_id
            FROM parents p JOIN splitgraph_meta.objects o ON p.parent_id = o.object_id)
        SELECT object_id FROM parents);
END
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- get_new_objects(object_ids): return objects in object_ids that don't exist in the object tree.
CREATE OR REPLACE FUNCTION splitgraph_api.get_new_objects(object_ids varchar[]) RETURNS varchar[] AS $$
BEGIN
    RETURN ARRAY(SELECT o
        FROM unnest(object_ids) o
        WHERE o NOT IN (SELECT object_id FROM splitgraph_meta.objects));
END
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- get_object_meta(object_ids): get metadata for objects
CREATE OR REPLACE FUNCTION splitgraph_api.get_object_meta(object_ids varchar[])
  RETURNS TABLE (
    object_id VARCHAR,
    format    VARCHAR,
    parent_id VARCHAR,
    namespace VARCHAR,
    size      BIGINT,
    index     JSONB) AS $$
BEGIN
   RETURN QUERY
   SELECT o.object_id, o.format, o.parent_id, o.namespace, o.size, o.index
   FROM splitgraph_meta.objects o
   WHERE o.object_id = ANY(object_ids);
END
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- get_object_locations(object_ids): get external locations for objects
CREATE OR REPLACE FUNCTION splitgraph_api.get_object_locations(object_ids varchar[])
  RETURNS TABLE (
    object_id VARCHAR,
    location  VARCHAR,
    protocol  VARCHAR) AS $$
BEGIN
   RETURN QUERY
   SELECT o.object_id, o.location, o.protocol
   FROM splitgraph_meta.object_locations o
   WHERE o.object_id = ANY(object_ids);
END
$$ LANGUAGE plpgsql SECURITY INVOKER;


--
-- TABLE API
--

-- get_tables(namespace, repository, image_hash): list all tables in a given image, their schemas and the fragments
-- they consist of.
CREATE OR REPLACE FUNCTION splitgraph_api.get_tables(_namespace varchar, _repository varchar, _image_hash varchar)
  RETURNS TABLE (
    table_name VARCHAR,
    table_schema JSONB,
    object_ids VARCHAR[]) AS $$
BEGIN
  RETURN QUERY
  SELECT t.table_name, t.table_schema, t.object_ids
  FROM splitgraph_meta.tables t
  WHERE t.namespace = _namespace AND t.repository = _repository AND t.image_hash = _image_hash;
END
$$ LANGUAGE plpgsql SECURITY INVOKER;