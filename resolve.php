<?php
class Resolver
{
    const MERGE_MATCH = '/<{3,}\s*HEAD.*\n((.|\n)*?)={4,}\s*\n((.|\n)*?)>{3,}+.*\n/';

    const MODE_REBASE = 'Unmerged paths:';

    const RESOLVE_BOTH = 'both modified:';
    const RESOLVE_ADDED = 'both added:';
    const RESOLVE_MODIFIED = 'modified:';

    const MODE_REBASE_END = 'Changes not staged for commit:';
    const MODE_ALL_END = 'Untracked files:';

    const PRESERVE_OLD = '$3';
    const PRESERVE_NEW = '$1';

    const DONT_AUTO_ADD = 1;
    const LINT_DONT_ADD = 2;
    const SAFE_AUTO_ADD = 4;
    const FAST_AUTO_ADD = 8;

    const VALID_MODE_RANGE = 15;
    const LINT_MODES = 6;
    const ADD_MODES = 12;

    protected $preserve = null;
    protected $addMethod = self::DONT_AUTO_ADD;
    protected $paths = array();

    /**
     * Constructor... obviously
     * @param array (assoc, uses keys to "guess" setters)
     * @return Resolver
     **/
    public function __construct(array $params)
    {
        foreach ($params as $k => $v)
        {
            $k = 'set'.ucfirst($k);
            if (method_exists($this, $k))
                $this->{$k}($v);
        }
    }

    /**
     * Main method. Process given paths according to specified mode
     * @param int $addMode = null Use class constants
     * @param array $files = null Array of paths
     * @return array
     **/
    public function resolveConflicts($addMode = null, array $files = null)
    {
        if ($addMode && is_array($addMode))
        {
            $files = $addMode;
            $addMode = null;
        }
        if ($addMode)
            $this->setAddMode($addMode);
        if ($files === null)
            $files = empty($this->paths) ? $this->getPathsFromGit() : $this->paths;
        $add = array();
        foreach ($files as $f)
        {
            $add[$f] = $this->resolveRebase($f);
        }
        if (($this->addMethod & self::LINT_MODES) === $this->addMethod)
            $add = $this->lintFiles($add);
        if (($this->addMethod & self::ADD_MODES) === $this->addMethod)
            $this->doAddResolved($add);
        return $this->getResult($add);
    }

    /**
     * checks given files for syntax errors, uses exec('php -l') to do so
     * @param array $files
     * @return array
     **/
    protected function lintFiles(array $files)
    {
        foreach ($files as $f => $exists)
        {
            switch (substr($f, -4))
            {
                case '.php':
                    if ($exists)
                    {
                        exec('php -l '.$f, $out, $status);
                        $out = $status != 0 ? 'ERROR' : implode('', $out);
                        if (strstr($out,'No syntax errors detected') === false)
                            $files[$f] = 'Syntax error: '.$out;
                        else
                            $files[$f] = 'Resolved - No syntax errors!';
                    }
                    break;
                case '.xml':
                    $dom = new DOMDocument;
                    if ($dom->load($f))
                    {
                        if ($dom->validate())
                            $files[$f] = 'DOM was parsed and validated';
                        else
                            $files[$f] = 'DOM was parsed, but DTD is either missing or markup does not conform';
                    }
                    else
                    {
                        $files[$f] = 'Syntax error: DOM cannot be parsed, possible invalid markup';
                    }
                break;
            }
        }
        return $files;
    }

    /**
     * create assoc array, ready for ResolverIO rendering
     * @param array $res
     * @return array
     */
    protected function getResult(array $res)
    {
        $out = array();
        foreach ($res as $file => $status)
        {
            $out[$file] = $status;
        }
        return $out;
    }

    /**
     * Adds resolved conflict through git add command
     * provided the file was processed (and lint was OK) successfully
     * @param array $resolved
     * @return array
     */
    protected function doAddResolved(array $resolved)
    {
        foreach ($resolved as $f => $status)
        {
            if ($status !== false && strstr($status, 'Syntax error:') === false)
            {
                exec('git add '.$f, $out, $s);
                $resolved[$f] = $s != 0 ? 'Error: '.implode(PHP_EOL, $out) : 'Added!';
            }
        }
        return $resolved;
    }


    /**
     * exec call to git status command, reads output, gets the
     * "Both modified" and "both added" paths
     * attempts to resolve the conflicts
     * @return array
     * @throw RuntimeException
     **/
    protected function getPathsFromGit()
    {
        exec('git status', $out, $status);
        if ($status != 0)
            throw new RuntimeException('Could not get git status');
        $this->paths = array();
        $len = strlen(self::RESOLVE_BOTH);//assign once, use in loop
        for ($i=0,$j=count($out);$i<$j;++$i)
        {
            if (strstr($out[$i], 'Unmerged paths:'))
            {
                while(($path = strstr($out[$i], self::RESOLVE_BOTH)) === false && ($path = strstr($out[$i], self::RESOLVE_ADDED)) === false && $i < $j)
                    ++$i;
                do {
                    $path = trim(
                        substr($path, $len)
                    );
                    $path = trim($path);
                    $ext = substr($path, -4);
                    if ($ext === '.php' || $ext === '.xml')
                        $this->paths[] = $path;
                } while(($path = strstr($out[++$i], self::RESOLVE_BOTH)) !== false || ($path = strstr($out[$i], self::RESOLVE_ADDED)) !== false);
            }
            if (strstr($out[$i], self::MODE_REBASE_END) !== false || strstr($out[$i], self::MODE_ALL_END) !== false)
                break;
        }
        return $this->paths;
    }

    /**
     * Checks if files exist, rewrites the file using preg_replace
     * @param string $file
     * @return bool
     */
    protected function resolveRebase($file)
    {
        if (!file_exists($file))
        {
            echo $file, ' Does seem to exist', PHP_EOL;
            return false;
        }
        $contents = file_get_contents($file);
        $replaced = preg_replace(
            self::MERGE_MATCH,
            $this->preserve,
            $contents
        );
        file_put_contents($file, $replaced);
        return true;
    }

    /**
     * setter for $paths property
     * @param array $paths <string>
     * @return Resolver
     */
    public function setPaths(array $paths)
    {
        $this->paths = $paths;
        return $this;
    }

    /**
     * Setter for mode property (preserve old/new part of diff conflict?)
     * @param int $mode (use constants)
     * @return Resolver
     * @throw InvalidArgumentException
     */
    public function setPreserve($mode = self::PRESERVE_OLD)
    {
        if ($mode !== self::PRESERVE_OLD && $mode !== self::PRESERVE_NEW)
            throw new InvalidArgumentException(
                '%s is an invalid mode, use class constants',
                $mode
            );
        $this->preserve = $mode;
        return $this;
    }

    /**
     * Setter for add-mode (don't add, quick 'n dirty, lint-check with/without adding)
     * @param int $mode (use class constants)
     * @return Resolver
     * @throw InvalidArgumentException
     */
    public function setAddMode($mode)
    {
        $mode = (int) $mode;
        if (($mode & self::VALID_MODE_RANGE) !== $mode || ($mode & ($mode-1)) !== 0)
            throw new InvalidArgumentException(
                sprintf(
                    'Unknown add-mode: %d, please use class constants',
                    $mode
                )
            );
        $this->addMethod = $mode;
        return $this;
    }

}

class ResolverIO
{
    /**
     * @var Resolver
     */
    protected $resolver = null;

    /**
     * @var array
     */
    protected $arguments = array(
        'paths'     => array(),
        'preserve'  => Resolver::PRESERVE_OLD,
        'addMode'   => Resolver::DONT_AUTO_ADD
    );

    protected $output = null;

    /**
     * Constructor, obviously...
     * @param Resolver $r = null (optional)
     * @return ResolverIO
     */
    public function __construct(Resolver $r = null)
    {
        $this->resolver = null;
    }

    /**
     * Accepts array argument, should be passed the CLI $argv array
     * @param array $args (use $argv => implies $args[0] is ignored!)
     * @param bool $cli = true
     * @return ResolverIO
     */
    public function resolveConflicts(array $args = array(), $cli = true)
    {
        if ($args && $cli)
            $this->initResolver($this->processArguments($args));
        $r = $this->getResolver();
        $this->output = $this->renderOutput(
            $r->resolveConflicts()
        );
        return $this;
    }

    /**
     * Get rendered output (stringified in table)
     * Default appends EOL char to this string, pass false if not desired
     * @param bool $appendEOL = true
     * @return string
     */
    public function getOutput($appendEOL = true)
    {
        if ($appendEOL === true)
            return $this->output.PHP_EOL;
        return $this->output;
    }

    /**
     * Set default settings, which will be used for Resolver
     * @param array $defaults
     * @return ResolverIO
     */
    public function setDefaults(array $defaults)
    {
        foreach ($this->argumenst as $k => $v)
        {
            if (isset($defaults[$k]))
                $this->arguments[$k] = $defaults[$k];
        }
        return $this;
    }

    /**
     * create (new) Resolver instance
     * @param array $params
     * @return ResolverIO
     */
    protected function initResolver(array $params)
    {
        $this->resolver = new Resolver($params);
        return $this;
    }

    /**
     * Lazy-loader for Resolver dependency
     * uses default arguments, can be set through ResolverIO::setDefaults
     * @return Resolver
     */
    public function getResolver()
    {
        if ($this->resolver === null)
        {
            $this->resolver = new Resolver(
                $this->arguments
            );
        }
        return $this->resolver;
    }

    /**
     * Extract params/defaults/arguments from passed array (CLI $argv)
     * the resulting array is an assoc array that can be used to initialize Resovler
     * @param array $args
     * @return array $params
     */
    public function processArguments(array $args)
    {
        $argMap = array(
            'p' => 'preserve',
            'm' => 'addMode',
            'new'   => Resolver::PRESERVE_NEW,
            'old'   => Resolver::PRESERVE_NEW,
            'fast'  => Resolver::FAST_AUTO_ADD,
            'safe'  => Resolver::SAFE_AUTO_ADD,
            'check' => Resolver::LINT_DONT_ADD,
            'resolve'   => Resolver::DONT_AUTO_ADD
        );
        $params = array(
            'preserve'  => Resolver::PRESERVE_OLD,
            'addMode'   => Resolver::DONT_AUTO_ADD,
            'paths'     => array()
        );
        for ($i=1, $j=count($args);$i<$j;++$i)
        {
            if ($args[$i]{0} !== '-')
                $params['paths'][] = $args[$i];
            else
            {
                $matches = explode(
                    '=',
                    str_replace(
                        '-',
                        '',
                        $args[$i]
                    )
                );
                $matches[0] = $matches[0]{0};
                if (!isset($argMap[$matches[0]]) || !isset($argMap[$matches[1]]))
                    throw new InvalidArgumentException($args[$i]. ' invalid CLI argument');
                $params[$argMap[$matches[0]]] = $argMap[$matches[1]];
            }
        }
        return $params;
    }

    /**
     * Render returned array from Resolve dependency into easy-to-display table
     * @param array $out (actually, input)
     * @return string
     */
    public function renderOutput(array $out)
    {
        $array = array(
            'File'      => array(),
            'Status'    => array()
        );
        $lengths = array(
            'File'      => 0,
            'Status'    => 0
        );
        foreach ($out as $path => $result)
        {
            $len = strlen($path)+2;
            if ($len > $lengths['File'])
                $lengths['File'] = $len;
            $array['File'][] = $path;
            if (is_bool($result))
            {
                $result = $result ? 'Success' : 'Failed';
            }
            $len = strlen($result) + 2;
            if ($len > $lengths['Status'])
                $lengths['Status'] = $len;
            $array['Status'][] = $result;
        }
        $line = '+'.str_repeat('-', $lengths['File']).'+'.str_repeat('-', $lengths['Status']).'+';
        $format = vsprintf(
            '|%%-%d.%1$ds|%%-%d.%2$ds|',
            $lengths
        );
        $table = array(
            $line,
            vsprintf($format,array_keys($array)),
            $line
        );
        for($i=0,$j=count($array['File']);$i<$j;++$i)
            $table[] = sprintf(
                $format,
                $array['File'][$i],
                $array['Status'][$i]
            );
        $table[] = $line;
        return implode(PHP_EOL, $table);
    }
}

//Only allow CLI runtime
if (PHP_SAPI !== 'cli')
    throw new RuntimeException(__FILE__. ' is a CLI-only script');

$io = new ResolverIO();//create our accessor instance

echo $io->resolveConflicts($argv)//pas cli arguments
    ->getOutput();//get output table, and pass to echo

