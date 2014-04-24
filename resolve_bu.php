<?php
class Resolver
{

    const MERGE_MATCH = '/\<{3,}\s*HEAD[^\n]*((\n|.)*?)={4,}((.|\n)+?)>{3,}[^\n]*/mi';

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

    public function __construct(array $params)
    {
        foreach ($params as $k => $v)
        {
            $k = 'set'.ucfirst($k);
            if (method_exists($this, $k))
                $this->{$k}($v);
        }
    }

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

    protected function lintFiles(array $files)
    {
        foreach ($files as $f => $exists)
        {
            if ($exists)
            {
                exec('php -l '.$f, $out, $status);
                $out = $status != 0 ? 'ERROR' : implode('', $out);
                if (strstr($out,'No syntax errors detected') === false)
                    $files[$f] = 'Syntax error: '.$out;
                else
                    $files[$f] = 'Resolved - No syntax errors!';
            }
        }
        return $files;
    }

    protected function getResult(array $res)
    {
        $out = array();
        foreach ($res as $file => $status)
        {
            $out[$file] = $status;
        }
        return $out;
    }

    protected function doAddResolved(array $resolved)
    {
        foreach ($resolved as $f => $status)
        {
            if ($status !== false)
            {
                exec('git add '.$f, $out, $s);
                $resolved[$f] = $s != 0 ? 'Error: '.implode(PHP_EOL, $out) : 'Added!';
            }
        }
        return $resolved;
    }

    protected function getPathsFromGit()
    {
        exec('git status', $out, $status);
        if ($status != 0)
            throw new RuntimeException('Could not get git status');
        $this->paths = array();
        for ($i=0,$j=count($out);$i<$j;++$i)
        {
            if (strstr($out[$i], 'Unmerged paths:'))
            {
                while(($path = strstr($out[$i], self::RESOLVE_BOTH)) === false && ($path = strstr($out[$i], self::RESOLVE_ADDED)) === false && $i < $j)
                    ++$i;
                $len = strlen(self::RESOLVE_BOTH);
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

    public function setPaths(array $paths)
    {
        $this->paths = $paths;
        return $this;
    }

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

if (PHP_SAPI !== 'cli')
    throw new RuntimeException(__FILE__. ' is a CLI-only script');

function processArguments(array $args)
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

function renderOutput(array $out)
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

$resolver = new Resolver(
    processArguments(
        $argv
    )
);
$output = $resolver->resolveConflicts();
echo renderOutput($output), PHP_EOL;
