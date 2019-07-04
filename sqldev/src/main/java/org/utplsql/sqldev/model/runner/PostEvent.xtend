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
package org.utplsql.sqldev.model.runner

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
abstract class PostEvent extends RealtimeReporterEvent {
	String startTime
	String endTime
	Double executionTime
	Counter counter
	String errorStack
	String serverOutput
	String warnings
	
	new() {
		counter = new Counter
	}
}