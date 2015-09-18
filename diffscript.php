<?php
//script to diff 2 MySQL databases and generate WORKING queries to sync one of them
//uses ugly exec calls at its heart, and the CLI params aren't properly checked
//using this script as-is is a terrible idea...

class Query
{
    /**
     * @var array
     */
    protected $lines = [];

    /**
     * @var array
     */
    protected $columns = [];

    /**
     * @var array
     */
    protected $columnDependencies = [];

    /**
     * @var array
     */
    protected $addIndexes = [];

    /**
     * @var array
     */
    protected $dropIndexes = [];

    /**
     * @var string
     */
    protected $queryString = null;

    /**
     * @var array
     */
    protected $foreignKeys = [];

    /**
     * @var bool
     */
    protected $isParsed = false;

    /**
     * @var array
     */
    protected $pkLines = [];

    /**
     * Constructor for Query -> pass the raw query string to rebuild
     * @param string $queryString
     */
    public function __construct($queryString)
    {
        $this->queryString = $queryString;
        //avoid DROP FOREIGN KEY duplicates (it happens...)
    }

    /**
     * Parse the query string
     * @return $this
     */
    public function parse()
    {
        if ($this->isParsed || strstr($this->queryString, 'ALTER TABLE') === false) {
            return $this;
        }
        $this->lines = array_unique(
            explode(PHP_EOL, $this->queryString)
        );
        $this->sanitizeExpressions()
            ->extractExpressions();
        $this->isParsed = true;
        return $this;
    }

    /**
     * Rebuild the query (order column fields, removes FK changes by default)
     * @param bool $includeFkChanges = false - set to true to include FK changes
     * @return string
     */
    public function rebuildQuery($includeFkChanges = false)
    {
        if (!$this->isParsed) {
            $this->parse();
            if ($this->isParsed === false) {
                return $this->queryString;
            }
        }
        //always keep first line :)
        $new = [
            $this->lines[0],
        ];
        if ($includeFkChanges) {
            while (strstr($this->foreignKeys[0], 'DROP') !== false) {
                $new[] = array_shift($this->foreignKeys);
            }
        }
        $new = $this->addPkLines($new, $includeFkChanges);
        $new = $this->addIndexLines($new, $includeFkChanges);
        if ($includeFkChanges) {
            foreach ($this->foreignKeys as $line) {
                $new[] = $this->lines[$line];
            }
        }
        $columnLines = $this->getSortedColumns();
        foreach ($columnLines as $line) {
            $new[] = $this->lines[$line];
        }
        if (count($new) == 1) {
            //we don't need an empty query
            return '';
        }
        $last = trim(array_pop($this->lines));
        if (strlen($last) == 1 && $last == ';') {
            $currentLast = array_pop($new);
            $new[] = str_replace(',', '', $currentLast);
        }
        $new[] = $last;//append last line
        return implode(PHP_EOL, $new);
    }

    /**
     * Add index lines to rebuilt query
     * @param array $new - current new query lines
     * @param bool $includeFks = false
     * @return array
     */
    protected function addIndexLines(array $new, $includeFks = false)
    {
        if (!$includeFks) {
            $this->removeIndexPairs();
        }
        foreach ($this->dropIndexes as $line) {
            $new[] = $this->lines[$line];
        }
        foreach ($this->addIndexes as $line) {
            $new[] = $this->lines[$line];
        }
        return $new;
    }

    /**
     * Add Primary key lines to rebuilt query
     * @param array $new - current new query lines
     * @param bool $includeFks = false
     * @return array
     */
    protected function addPkLines(array $new, $includeFks = false)
    {
        if (!$includeFks) {
            $pkLines = count($this->pkLines);
            if ($pkLines) {
                //removing + adding PK lines is mostly because of FK changes
                do {
                    $lastLine = trim(array_pop($this->lines));
                } while (!$lastLine);
                $this->lines[] = preg_replace(
                    '/AUTO_INCREMENT=\d+\s*,?/',
                    '',
                    $lastLine
                );
                if ($pkLines > 1) {
                    //this happens when FK's are changed
                    return $new;
                }
            } else {
                return $new;
            }
        }
        foreach ($this->pkLines as $lineNr) {
            $new[] = $this->lines[$lineNr];
        }
        return $new;
    }

    /**
     * Remove duplicate index lines if FK changes are excluded
     * Changes to FK's often result in DROP INDEX + ADD INDEX expressions
     * @return $this
     */
    protected function removeIndexPairs()
    {
        $add = [];
        foreach ($this->addIndexes as $name => $line) {
            if (isset($this->dropIndexes[$name])) {
                unset($this->dropIndexes[$name]);//remove drop statement
            } else {
                $add[$name] = $line;
            }
        }
        $this->addIndexes = $add;
        return $this;
    }

    /**
     * get the lines for column changes in correct order
     * mysqldiff uses AFTER field_name, which only works if the field_name
     * does not occur in later changes:
     * eg: - this fails ->
     *  ADD COLUMN foo INT(11) NULL AFTER bar
     *  CHANGE COLUMN bar bar varchar(255)
     * This method changes the order to the working version:
     *  CHANGE COLUMN bar bar varchar(255)
     *  ADD COLUMN foo INT(11) NULL AFTER bar
     *
     * @return array
     */
    protected function getSortedColumns()
    {
        $columnLines = [];
        foreach ($this->columns as $colName => $lineNr) {
            if (!in_array($lineNr, $columnLines)) {
                $columnLines = $this->prependColumnDependencies(
                    $colName,
                    $columnLines
                );
                $columnLines[] = $lineNr;
            }
        }
        return $columnLines;
    }

    /**
     * Resolves the column change dependencies recursively
     * and should only be called by getSortedColumns
     * @param string $name - name of field for which to prepend dependencies
     * @param array $stack - current lines already in new query
     * @return array - the updated stack
     */
    private function prependColumnDependencies($name, array $stack)
    {
        $depends = $this->columnDependencies[$name];
        if (!$depends || !array_key_exists($depends, $this->columns)) {
            return $stack;
        }
        $line = $this->columns[$depends];
        if (!in_array($line, $stack)) {
            $stack = $this->prependColumnDependencies(
                $depends,
                $stack
            );
            $stack[] = $line;
        }
        return $stack;
    }

    /**
     * Sanitize the query - mysqldiff does not properly escape reserved keywords
     * nor does it handle dodgy field names (containing dashes)
     * @return $this
     */
    protected function sanitizeExpressions()
    {
        foreach ($this->lines as $k => $line) {
            //lines that are indented are all we care about
            if ($line{0} === ' ') {
                //surround keywords or dashed field names with backticks
                $this->lines[$k] = preg_replace(
                    '/(?<=[\s,])(sql|fast|status|procedure|[\w_]+-[\w_]+)(?=[\s,\b])/', 
                    '`$1`', 
                    $line
                );
            }
        }
        return $this;
    }

    /**
     * breaks up the queryString passed to constructor and groups lines
     * accordingly: index changes, column changes, PK and FK lines etc...
     *
     * @return $this
     */
    protected function extractExpressions()
    {
        $columnOps = [];
        foreach ($this->lines as $k => $line) {
            //statement does stuff with columns?
            if ($line{0} === ' ') {
                if (strstr($line, 'COLUMN')) {
                    $parts = explode(' ', trim($line));//remove leading spaces
                    $name = str_replace('`', '', $parts[2]);//third word is always column name
                    $depends = null;
                    if (in_array('AFTER', $parts)) {
                        do {
                            //sometimes there's a space between AFTER colname ,
                            $depends = str_replace(',', '', array_pop($parts));
                        } while (!$depends);
                    }
                    $this->columns[$name] = $k;//column expression found on line $k
                    $this->columnDependencies[$name] = $depends;
                } elseif (strstr($line, 'FOREIGN KEY')) {
                    if (strstr($line, 'DROP')) {
                        array_unshift($this->foreignKeys, $k);//prepend drop statements
                    } else {
                        $this->foreignKeys[] = $k;//line operating on FK constraints
                    }
                } elseif (strstr($line, 'INDEX')) {
                    $parts = explode(' ',
                        str_replace(
                            'UNIQUE ',
                            '',
                            trim($line)
                        )
                    );
                    $name = str_replace(
                        [',','`'], '', $parts[2]);//index name in DROP INDEX x or ADD INDEX x
                    if ($parts[0] === 'DROP') {
                        $this->dropIndexes[$name] = $k;
                    } else {
                        $this->addIndexes[$name] = $k;
                    }
                } elseif (strstr($line, 'PRIMARY KEY')) {
                    $this->pkLines[] = $k;
                }
            }
        }
        return $this;
    }
}

class DbDiff
{
    /**
     * @var array
     */
    protected $options = [
        'base'          => 'new_schema',
        'host'          => '127.0.0.1',
        'user'          => 'root',
        'pass'          => 'root',
        'compare'       => 'db_to_upgrade',
        'compareHost'   => null,
        'output'        => null,
        'help'          => null,
        'execute'       => null,
    ];

    /**
     * @var array
     */
    protected $shortMap = [
        'base'          => 'b',
        'host'          => 's',
        'user'          => 'u',
        'pass'          => 'p',
        'compare'       => 'c',
        'compareHost'   => 'k',
        'output'        => 'o',
        'help'          => 'h',
        'execute'       => 'x',
    ];

    /**
     * @var string
     */
    protected $commandFormat = null;

    /**
     * @var PDO
     */
    protected $db = null;

    /**
     * @var array
     */
    protected $output = [];

    /**
     * Constructor
     */
    public function __construct()
    {
        $short = implode(':', $this->shortMap);
        str_replace('h:x', 'hx', $short);
        $long = [];
        foreach (array_keys($this->shortMap) as $key) {
            if ($key !== 'help' && $key !== 'execute') {
                $key .= ':';
            }
            $long[] = $key;
        }
        $options = getopt($short, $long);
        foreach ($options as $k => $v) {
            if (!array_key_exists($k, $this->options)) {
                if (in_array($k, $this->shortMap)) {
                    $k = array_search($k, $this->shortMap);
                } else {
                    $this->usage(1, $k);
                }
            }
            $this->options[$k] = $v;
        }
        if ($this->options['compareHost'] === null) {
            $this->options['compareHost'] = $this->options['host'];
        }
        if ($this->options['help'] !== null) {
            $this->usage();
        }
    }

    public function diffDb()
    {
        $tables = $this->getTables();
        $command = $this->getCommand();
        foreach ($tables as $table) {
            $last = exec(
                sprintf($command, $table), $out, $status
            );
            if ($status == 0) {
                $out = implode(
                    PHP_EOL,
                    $this->diffStringToSQL($out)
                );
                $this->output[] = $this->processQueries($out);
                $out = [];
            }
        }
    }

    /**
     * Write output
     * @return $this
     */
    public function getOutput()
    {
        $execute = $this->options['execute'] !== null;
        if ($this->options['output'] === null) {
            if ($execute) {
                file_put_contents(
                    'tmpfile.sql', 
                    implode(PHP_EOL, $this->output)
                );
                $credentials = $this->getExecuteCredentials();
                $command = sprintf(
                    'mysql -h %s -u %s -p %s --one-database %s < tmpfile.sql',
                    $credentials['host'],
                    $credentials['user'],
                    $credentials['pass'],
                    $this->options['compare']
                );
                echo exec($command, $out, $status);
                if ($status) {
                    echo implode(PHP_EOL, $out);
                }
                unlink('tmpfile.sql');
            }
            echo implode(PHP_EOL, $this->output);
        } else {
            file_put_contents(
                $this->options['output'],
                implode(PHP_EOL, $this->output)
            );
            if ($execute) {
                $credentials = $this->getExecuteCredentials();
                $command = sprintf(
                    'mysql -h %s -u %s -p %s --one-database %s < %s',
                    $credentials['host'],
                    $credentials['user'],
                    $credentials['pass'],
                    $this->options['compare'],
                    $this->options['output']
                );
                echo exec($command, $out, $status);
                if ($status) {
                    echo implode(PHP_EOL, $out);
                }
            }
        }
        return $this;
    }

    private function getExecuteCredentials()
    {
        $credentials = [
            'host'  => $this->options['host'],
            'user'  => $this->options['user'],
            'pass'  => $this->options['pass'],
        ];
        if ($this->options['compareHost'] != $this->options['host']) {
            $parts = explode('@', $this->options['compareHost']);
            $credentials['host'] = array_pop($parts);
            $login = explode(':', $parts[0]);
            $credentials['user'] = $login[0];
            $credentials['pass'] = $login[1];
        }
        return $credentials;
    }

    /**
     * Extracts all queries from the raw command output
     * The queries are processed using Query class, and injected into the raw output
     * @param string $raw
     * @return string
     */
    protected function processQueries($raw)
    {
        preg_match_all('/^[A-Z][^;]+;/m', $raw, $matches);
        foreach ($matches[0] as $query) {
            $rebuild = new Query($query);
            $raw = str_replace($query, $rebuild->rebuildQuery(), $raw);
        }
        return $raw;
    }

    /**
     * Comments out parts of the output that aren't part of the query strings
     * @param array $output
     * @return array
     */
    protected function diffStringToSQL(array $output)
    {
        $result = [];
        foreach ($output as $line) {
            if (preg_match('/^(#|ERROR|Compare|Success)/', $line)) {
                $line = '-- ' . $line;
            }
            $result[] = $line;
        }
        return $result;
    }

    /**
     * Get the base command, with only sprintf format specifiers for table names
     * @return string
     */
    protected function getCommand()
    {
        $format = $this->getCommandFormat();
        //compareHost was specified
        if (strstr($format, 'server2') !== false) {
            if (!preg_match('/[^:]+:[^@]@.+/', $this->options['compareHost'])) {
                $this->options['compareHost'] = sprintf(
                    '%s:%s@%s',
                    $this->options['user'],
                    $this->options['pass'],
                    $this->options['compareHost']
                );
            }
            $command = sprintf(
                $format,
                $this->options['compareHost'],
                $this->options['host'],
                $this->options['user'],
                $this->options['pass'],
                $this->options['compare'],
                $this->options['base']
            );
        } else {
            $command = sprintf(
                $format,
                $this->options['host'],
                $this->options['user'],
                $this->options['pass'],
                $this->options['compare'],
                $this->options['base']
            );
        }
        return $command;
    }

    protected function getCommandFormat()
    {
        if ($this->commandFormat === null) {
            if ($this->options['compareHost'] === $this->options['host']) {
                $this->commandFormat = 'mysqldiff --server1=%s:%s@%s %s.%%s:%s.%%1$s --difftype=sql';
            } else {
                $this->commandFormat = 'mysqldiff --server1=%s --server2=%s:%s@%s %s.%%s:%s.%%1$s --difftype=sql';
            }
        }
        return $this->commandFormat;
    }

    /**
     * Get the base DB connection
     * @return PDO
     */
    public function getDb()
    {
        if (!$this->db) {
            $dsn = sprintf(
                'mysql:%s;dbname=%s;charset=utf8',
                $this->options['host'],
                $this->options['base']
            );
            $this->db = new PDO(
                $dsn,
                $this->options['user'],
                $this->options['pass'],
                [
                    PDO::ATTR_ERRMODE   => PDO::ERRMODE_EXCEPTION,
                ]
            );
        }
        return $this->db;
    }

    /**
     * @return array
     */
    protected function getTables()
    {
        $db = $this->getDb();
        $stmt = $db->query(
            sprintf(
                'SHOW tables FROM %s',
                $this->options['base']
            )
        );
        $tableNames = [];
        while ($row = $stmt->fetch()) {
            $tableNames[] = $row[0];
        }
        return $tableNames;
    }

    /**
     * Display help && exit
     * @param int $exitCode = 0
     */
    public function usage($exitCode = 0, $opt = null)
    {
        if ($opt) {
            echo 'UNKNOWN OPTION "' . $opt . '"' . PHP_EOL;
        }
        echo 'Diff 2 databases - uses mysqldiff, but processes the output' . PHP_EOL;
        printf(
            '    php %s -[bsoupxckh]:' . PHP_EOL,
            __FILE__
        );
        echo '    -b|--base       : The target schema (not the one you want to update)' . PHP_EOL
         .   '    -s|--host       : The host IP for the base schema' . PHP_EOL
         .   '    -u|--user       : User name for base schema' . PHP_EOL
         .   '    -p|--pass       : The pass for base schema' . PHP_EOL
         .   '    -c|--compare    : The schema you want to update/sync with the base schema' . PHP_EOL
         .   '    -k|--compareHost: The host for the compare schema (defaults to -h)' . PHP_EOL
         .   '                      this may contain login info: user:pass@127.0.0.1' . PHP_EOL
         .   '    -o|--output     : Send output to a file [default is stdout]' . PHP_EOL
         .   '    -h|--help       : Display this message' . PHP_EOL
         .   '    -x|--execute    : Execute the generated queries [not recommended]' . PHP_EOL;
         exit($exitCode);
    }
}

//$proc = new DbDiff();
//$proc->diffDb();
//$proc->getOutput();

$db = new PDO(
    'mysql:127.0.0.1;dbname=new_schema;charset=utf8',
    'user',
    'pass', 
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]
);

$stmt = $db->query('SHOW tables FROM new_schema');

$command = 'mysqldiff --server1=user:pass@localhost db_to_upgrade.%s:new_schema.%1$s --difftype=sql';

while($table = $stmt->fetch()) {
    $last = exec(sprintf($command, $table[0]), $out, $status);
    if ($status == 0) {
        echo processQueries(implode(PHP_EOL, diffStringToSQL($out)));
        $out = [];
    }
}

if ($out) {
    echo processQueries(implode(PHP_EOL, diffStringToSQL($out)));
}


function diffStringToSQL(array $output)
{
    $result = [];
    foreach ($output as $line) {
        if (preg_match('/^(#|ERROR|Compare|Success)/', $line)) {
            $line = '-- ' . $line;
        }
        $result[] = $line;
    }
    return $result;
}

/**
 * Extracts all queries from the raw command output
 * The queries are processed using Query class, and injected into the raw output
 * @param string $raw
 * @return string
 */
function processQueries($raw)
{
    preg_match_all('/^[A-Z][^;]+;/m', $raw, $matches);
    foreach ($matches[0] as $query) {
        $rebuild = new Query($query);
        $raw = str_replace($query, $rebuild->rebuildQuery(), $raw);
    }
    return $raw;
}
