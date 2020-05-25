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
package org.utplsql.sqldev.model.runner;

import org.springframework.core.style.ToStringCreator;
import org.utplsql.sqldev.model.UtplsqlToStringStyler;

public class PostSuiteEvent extends PostEvent {
    private String id;

    @Override
    public String toString() {
        return new ToStringCreator(this, UtplsqlToStringStyler.INSTANCE)
                // ancestor
                .append("startTime", getStartTime())
                .append("endTime", getEndTime())
                .append("executionTime", getExecutionTime())
                .append("counter", getCounter())
                .append("errorStack", getErrorStack())
                .append("serverOutput", getServerOutput())
                .append("warnings", getWarnings())
                // local
                .append("id", id)
                .toString();
    }
    
    public String getId() {
        return id;
    }

    public void setId(final String id) {
        this.id = id;
    }
}
