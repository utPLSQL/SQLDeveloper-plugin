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
package org.utplsql.sqldev.test.coverage;

import java.util.Arrays;
import java.util.Collections;

import org.junit.Assert;
import org.junit.Test;
import org.utplsql.sqldev.coverage.CodeCoverageReporter;
import org.utplsql.sqldev.model.DatabaseTools;
import org.utplsql.sqldev.model.SystemTools;
import org.utplsql.sqldev.test.AbstractJdbcTest;


public class CodeCoverageReporterDialogTest extends AbstractJdbcTest {

    @Test
    public void layout() {
        final CodeCoverageReporter reporter = new CodeCoverageReporter(Collections.singletonList("SCOTT"),
                Arrays.asList("a", "b", "c"), DatabaseTools.getConnection(dataSource));
        reporter.showParameterWindow();
        SystemTools.sleep(4 * 1000);
        Assert.assertNotNull(reporter.getFrame());
        reporter.getFrame().exit();
    }
}
