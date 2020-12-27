/*
 * Copyright 2019 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
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
package org.utplsql.sqldev.model;

import java.util.LinkedHashMap;
import java.util.Map;

public class LimitedLinkedHashMap<K, V> extends LinkedHashMap<K, V> {
    private static final long serialVersionUID = -4184317926729190411L;
    private final int maxEntries;

    public LimitedLinkedHashMap(final int maxEntries) {
        super((maxEntries + 1), 1.0f, false);
        this.maxEntries = maxEntries;
    }

    @Override
    public boolean removeEldestEntry(final Map.Entry<K, V> eldest) {
        return (size() > maxEntries);
    }

    public int getMaxEntries() {
        return maxEntries;
    }
}
