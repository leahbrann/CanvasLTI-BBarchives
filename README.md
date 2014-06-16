CanvasLTI-BBarchives
====================

Basic LTI extension to Canvas for downloading Blackboard archive files

<ul>Assumptions:
  <li>blackboard.db in form of: create table Courses(id INTEGER PRIMARY KEY AUTOINCREMENT, Course_Name varchar(150), Course_ID varchar(100), Instructor_ID varchar(50));</li>
  <li>.env file with ARCHIVE_FILE_PATH defined, archive files in form of Course_ID.zip</li>
</ul>
authentication/structure generously borrowed from https://github.com/instructure/lti_tool_provider_example
