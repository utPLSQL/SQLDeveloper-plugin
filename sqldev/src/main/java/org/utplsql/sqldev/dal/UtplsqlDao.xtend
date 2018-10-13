/*
 * Copyright 2018 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 package org.utplsql.sqldev.dal

import java.sql.Connection
import java.util.List
import org.oddgen.sqldev.generators.model.Node
import org.springframework.dao.DataAccessException
import org.springframework.dao.EmptyResultDataAccessException
import org.springframework.jdbc.core.BeanPropertyRowMapper
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.datasource.SingleConnectionDataSource
import org.utplsql.sqldev.model.ut.Annotation

class UtplsqlDao {
	public static val UTPLSQL_PACKAGE_NAME = "UT" 
	var Connection conn
	var JdbcTemplate jdbcTemplate
	// cache fields
	Boolean cachedDbaViewAccessible
	String cachedUtplsqlSchema
	Boolean cachedUtAnnotationManagerInstalled

	new(Connection connection) {
		conn = connection
		jdbcTemplate = new JdbcTemplate(new SingleConnectionDataSource(conn, true))
	}
	
	def boolean isDbaViewAccessible() {
		if (cachedDbaViewAccessible === null) {
			try {
				val sql = '''
					SELECT 1
					  FROM dba_objects
					 WHERE 1=2
				'''
				jdbcTemplate.execute(sql)
				cachedDbaViewAccessible = true
			} catch (DataAccessException e) {
				cachedDbaViewAccessible = false
			}
		}
		return cachedDbaViewAccessible.booleanValue
	}
	
	/**
	 * Gets the schema name of the utPLSQL installation.
	 * 
	 * @return utPLSQL schema or null if no utPLSQL is not installed
	 * @throws DataAccessException if there is a problem
	 */
	def String getUtplsqlSchema() {
		if (cachedUtplsqlSchema === null) {
			val sql = '''
				SELECT table_owner
				  FROM «IF dbaViewAccessible»dba«ELSE»all«ENDIF»_synonyms
				 WHERE owner = 'PUBLIC'
				   AND synonym_name = '«UTPLSQL_PACKAGE_NAME»'
				   AND table_name = '«UTPLSQL_PACKAGE_NAME»'
			'''
			try {
				val schema = jdbcTemplate.queryForObject(sql, String)
				cachedUtplsqlSchema = schema
			} catch (EmptyResultDataAccessException e) {
				cachedUtplsqlSchema = null	
			}
		}
		return cachedUtplsqlSchema
	}
	
	/**
	 * Checks if the package ut_annotation_manager is installed.
	 * This package has been introduced with utPLSQL 3.0.4.
	 * This version is a prerequisite to identify 
	 * utPLSQL unit test procedures.
	 * 
	 * @return true if ut_annotation_manager package has been found
	 * @throws DataAccessException if there is a problem
	 */
	def boolean isUtAnnotationManagerInstalled() {
		if (cachedUtAnnotationManagerInstalled === null) {
			cachedUtAnnotationManagerInstalled = false
			if (utplsqlSchema !== null) {
				val sql = '''
					SELECT count(*)
					  FROM «IF dbaViewAccessible»dba«ELSE»all«ENDIF»_objects
					 WHERE owner = '«utplsqlSchema»'
					   AND object_type = 'PACKAGE'
					   AND object_name = 'UT_ANNOTATION_MANAGER'
				'''
				val found = jdbcTemplate.queryForObject(sql, Integer)
				cachedUtAnnotationManagerInstalled = found == 1
			}
		}
		return cachedUtAnnotationManagerInstalled
	}
	
	/**
	 * Checks if utPLSQL tests exist
	 * 
	 * @param owner schema name, mandatory, case-insensitive
	 * @param objectName name of the package or package body, optional, case-insensitive
	 * @param subobjectName name of the procedure, optional, case-insensitive
	 * @return true if at least one test has been found
	 * @throws DataAccessException if a utPLSQL version less than 3.0.4 is installed or if there are other problems
	 */
	def boolean containsUtplsqlTest(String owner, String objectName, String subobjectName) {
		try {
			val sql = '''
				SELECT count(
				          CASE 
				             WHEN a.name = 'test' 
				                  AND (upper(a.subobject_name) = upper(?) OR ? IS NULL) 
				             THEN 
				               1 
				             ELSE 
				               NULL 
				          END
				       )
				  FROM TABLE(«utplsqlSchema».ut_annotation_manager.get_annotated_objects(upper(?), 'PACKAGE')) o
				 CROSS JOIN TABLE(o.annotations) a
				 WHERE (o.object_name = upper(?) OR ? IS NULL)
				   AND a.name IN ('test', 'suite')
				HAVING count(
				          CASE 
				             WHEN a.name = 'suite' THEN 
				                1 
				             ELSE 
				                NULL 
				          END
				       ) > 0
			'''
			val found = jdbcTemplate.queryForObject(sql, Integer, #[subobjectName, subobjectName, owner, objectName, objectName])
			return found > 0
		} catch (EmptyResultDataAccessException e) {
			return false	
		}
	} 
	
	def boolean containsUtplsqlTest(String owner) {
		return containsUtplsqlTest(owner, null, null)
	}
	
	def boolean containsUtplsqlTest(String owner, String objectName) {
		return containsUtplsqlTest(owner, objectName, null)
	}
	
	/**
	 * Gets a list of utPLSQL annotations for a given PL/SQL package specification
	 * 
	 * @param owner schema name, mandatory, case-insensitive
	 * @param objectName name of the package or package body, optional, case-insensitive
	 * @return list of Annotation with name 'suite' or 'test'
	 * @throws DataAccessException if a utPLSQL version less than 3.0.4 is installed or if there are other problems
	 */
	def List<Annotation> annotations(String owner, String objectName) {
		val sql = '''
			SELECT o.object_owner, o.object_type, o.object_name, a.name, a.text, a.subobject_name
			  FROM TABLE(«utplsqlSchema».ut_annotation_manager.get_annotated_objects(upper(?), 'PACKAGE')) o
			 CROSS JOIN TABLE(o.annotations) a
			 WHERE o.object_name = upper(?)
		'''
		val result = jdbcTemplate.query(sql, new BeanPropertyRowMapper<Annotation>(Annotation), #[owner, objectName])
		return result
	}

	/**
	 * Gets a list of public units in the object type 
	 * 
	 * @param objectType expected object types are PACKAGE, TYPE, FUNCTION, PROCEDURE
	 * @param objectName name of the object
	 * @return list of the public units in the object type
	 * @throws DataAccessException if there is a problem
	 */
	def List<String> units(String objectType, String objectName) {
		if (objectType == "PACKAGE" || objectType == "TYPE") {
			val sql = '''
				SELECT procedure_name
				  FROM user_procedures
				 WHERE object_type = ?
				   AND object_name = ?
				   AND procedure_name IS NOT NULL
				 GROUP BY procedure_name
				 ORDER BY min(subprogram_id)
			'''
			val result = jdbcTemplate.queryForList(sql, String, #[objectType, objectName])
			return result
		} else {
			return #[objectName]
		}
	}
	
	/**
	 * Gets a list of oddgen's nodes as candidates to create utPLSQL test packages.
	 * Candidates are packages, types, functions and procedures in the current user.
	 * 
	 * This functions must be called from an oddgen generator only, since the Node is not
	 * defined in the utPLSQL extension.
	 * 
	 * @param objectType expected object types are PACKAGE, TYPE, FUNCTION, PROCEDURE
	 * @return list of the oddgen nodes for the requested object type
	 * @throws DataAccessException if there is a problem
	 */
	def List<Node> testables(String objectType) {
		var String sql;
		if (objectType == "PACKAGE") {
			sql = '''
				SELECT DISTINCT 
				       object_type || '.' || object_name AS id,
				       object_type AS parent_id,
				       1 AS leaf,
				       1 AS generatable,
				       1 AS multiselectable
				  FROM user_procedures
				 WHERE object_type = ?
				   AND procedure_name IS NOT NULL
				   AND object_name NOT IN (
				          SELECT object_name
					        FROM TABLE(«utplsqlSchema».ut_annotation_manager.get_annotated_objects(USER, 'PACKAGE'))
				       )
			'''
		}
		else if (objectType == "TYPE") {
			sql = '''
				SELECT DISTINCT 
				       object_type || '.' || object_name AS id,
				       object_type AS parent_id,
				       1 AS leaf,
				       1 AS generatable,
				       1 AS multiselectable
				  FROM user_procedures
				 WHERE object_type = ?
				   AND procedure_name IS NOT NULL
			'''
		}
		else  {
			sql = '''
				SELECT object_type || '.' || object_name AS id,
				       object_type AS parent_id,
				       1 AS leaf,
				       1 AS generatable,
				       1 AS multiselectable
				  FROM user_objects
				 WHERE object_type = ?
				   AND generated = 'N'
			'''
		}
		val jdbcTemplate = new JdbcTemplate(new SingleConnectionDataSource(conn, true))
		val nodes = jdbcTemplate.query(sql, new BeanPropertyRowMapper<Node>(Node), #[objectType])
		return nodes		
	}

	/**
	 * Gets a list of oddgen's nodes as candidates to run utPLSQL tests.
	 * 
	 * This functions must be called from an oddgen generator only, since the Node is not
	 * defined in the utPLSQL extension.
	 * 
	 * @return list of oddgen nodes (complete hierarchy loaded eagerly)
	 * @throws DataAccessException if there is a problem
	 */
	def List<Node> runnables() {
		var sql = '''
			WITH 
			   base AS (
			      SELECT rownum AS an_id,
			             o.object_owner,
			             o.object_type,
			             o.object_name,
			             lower(a.name) AS name,
			             a.text,
			             a.subobject_name
			        FROM table(ut3.ut_annotation_manager.get_annotated_objects(user, 'PACKAGE')) o
			       CROSS JOIN table(o.annotations) a
			       WHERE lower(a.name) in ('suite', 'suitepath', 'endcontext', 'test')
			          OR lower(a.name) = 'context' AND regexp_like(text, '(\w+)(\.\w+)*')
			   ),
			   suite AS (
			      SELECT object_owner, object_type, object_name, text AS suite_description
			        FROM base
			       WHERE name = 'suite'
			   ),
			   suitepath as (
			      SELECT object_owner, object_type, object_name, text AS suitepath 
			        FROM base
			       WHERE name = 'suitepath'
			   ),
			   context_base AS (
			      SELECT an_id,
			             lead(an_id) over (partition by object_owner, object_type, object_name order by an_id) AS an_id_end,
			             object_owner,
			             object_type,
			             object_name,
			             name,
			             lead(name) over (partition by object_owner, object_type, object_name order by an_id) AS name_end,
			             text as context
			        FROM base
			       WHERE name IN ('context', 'endcontext')
			   ),
			   context as (
			      SELECT an_id, an_id_end, object_owner, object_type, object_name, context
			        FROM context_base
			       WHERE name = 'context' 
			         AND name_end = 'endcontext'
			   ),
			   test AS (
			      SELECT b.an_id,
			             b.object_owner,
			             b.object_type,
			             b.object_name,
			             p.suitepath,
			             c.context,
			             b.subobject_name,
			             b.text AS test_description
			        FROM base b
			        LEFT JOIN suitepath p
			          ON p.object_owner = b.object_owner
			             AND p.object_type = b.object_type
			             AND p.object_name = b.object_name
			        LEFT JOIN context c
			          ON c.object_owner = b.object_owner
			             AND c.object_type = b.object_type
			             AND c.object_name = b.object_name
			             AND b.an_id BETWEEN c.an_id AND c.an_id_end
			       WHERE name = 'test'
			         AND (b.object_owner, b.object_type, b.object_name) IN (
			                SELECT object_owner, object_type, object_name
			                  FROM suite
			             )
			   ),
			   suite_tree AS (
			      SELECT null AS parent_id,
			             'SUITE' AS id,
			             'All Suites' AS name,
			             'All utPLSQL test suites' AS description,
			             'PACKAGE_FOLDER_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM dual
			      UNION ALL
			      SELECT DISTINCT 
			             'SUITE' AS parent_id,
			             object_owner || '.' || object_name AS id,
			             object_name AS name,
			             null AS description,
			             'PACKAGE_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM test
			      UNION ALL
			      SELECT object_owner || '.' || object_name AS parent_id,
			             object_owner || '.' || object_name || '.' || subobject_name AS id,
			             subobject_name AS name,
			             null AS description,
			             'PROCEDURE_ICON' AS iconName,
			             'Yes' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM test
			   ),
			   suitepath_base AS (
			      SELECT DISTINCT 
			             suitepath 
			        FROM suitepath
			   ),
			   gen AS (
			      SELECT rownum AS pos
			        FROM xmltable('1 to 100')
			   ),
			   suitepath_part AS (
			      SELECT DISTINCT
			             substr(suitepath, 1, instr(suitepath || '.', '.', 1, g.pos) -1) AS suitepath
			        FROM suitepath_base b
			        JOIN gen g
			          ON g.pos <= regexp_count(suitepath, '\w+')
			   ),
			   suitepath_tree AS (
			      SELECT NULL AS parent_id,
			             'SUITEPATH' AS id,
			             'All Suitepaths' AS name,
			             'All utPLSQL test suitepathes' AS description,
			             'FOLDER_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM dual
			      UNION ALL
			      SELECT CASE
			                WHEN regexp_replace(suitepath,'\.?\w+$','') IS NULL THEN
			                   'SUITEPATH'
			                ELSE 
			                   USER || ':' || regexp_replace(suitepath,'\.?\w+$','')
			             END AS parent_id,
			             USER || ':' || suitepath AS id,
			             regexp_substr(suitepath, '\.?(\w+$)', 1, 1, NULL, 1) AS name,
			             null AS description,
			             'FOLDER_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM suitepath_part
			      UNION ALL
			      SELECT DISTINCT 
			             object_owner || ':' || suitepath AS parent_id,
			             object_owner || ':' || suitepath || '.' || object_name AS id,
			             object_name AS name,
			             null AS description,
			             'PACKAGE_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM test
			       WHERE suitepath IS NOT NULL
			      UNION ALL
			      SELECT DISTINCT 
			             object_owner || ':' || suitepath || '.' || object_name AS parent_id,
			             object_owner || ':' || suitepath || '.' || object_name || '.' || context AS id,
			             context AS name,
			             null AS description,
			             'FOLDER_ICON' AS iconName,
			             'No' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM test
			       WHERE suitepath IS NOT NULL
			         AND context IS NOT NULL
			      UNION ALL
			      SELECT object_owner || ':' || suitepath || '.' || object_name || CASE WHEN context IS NOT NULL THEN '.' || context END AS parent_id,
			             object_owner || ':' || suitepath || '.' || object_name || CASE WHEN context IS NOT NULL THEN '.' || context END || '.' || subobject_name AS id,
			             subobject_name AS name,
			             null AS description,
			             'PROCEDURE_ICON' AS iconName,
			             'Yes' AS leaf,
			             'Yes' AS generatable,
			             'Yes' AS multiselectable,
			             'Yes' AS relevant
			        FROM test
			       WHERE suitepath IS NOT NULL
			   ),
			   tree AS (
			      SELECT parent_id, id, name, description, iconName, leaf, generatable, multiselectable, relevant
			       FROM suite_tree
			      UNION ALL
			      SELECT parent_id, id, name, description, iconName, leaf, generatable, multiselectable, relevant
			       FROM suitepath_tree
			   )
			SELECT parent_id, id, name, description, iconName, leaf, generatable, multiselectable, relevant
			  FROM tree
		'''
		val jdbcTemplate = new JdbcTemplate(new SingleConnectionDataSource(conn, true))
		val nodes = jdbcTemplate.query(sql, new BeanPropertyRowMapper<Node>(Node))
		return nodes		
	}	 

}