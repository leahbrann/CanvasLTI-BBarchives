CanvasLTI-BBarchives
====================

Basic LTI extension to Canvas for downloading Blackboard archive files

<ul>Assumptions:
  <li>Postgres db table in form of: CREATE TABLE courses (
    id BIGSERIAL PRIMARY KEY,
    course_name character varying(150),
    course_id character varying(100),
    instructor_id character varying(50)
)</li>
  <li>.env file with ARCHIVE_FILE_PATH defined, archive files in form of Course_ID.zip</li>
</ul>
authentication/structure generously borrowed from https://github.com/instructure/lti_tool_provider_example
