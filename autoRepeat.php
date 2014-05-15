<?php
//create cmd:
$cmd = '/usr/bin/env php ';
$params = array(
    'count' => 0,
    'path'  => realpath(dirname(__FILE__)),
    'input' => null,
    'output'=> null,
    'script'=> 'script.php',
    'args'  => '',
    'env'   => array()
);
$flags = array(
    'c'    => 'count',
    'p'    => 'path',
    'i'    => 'input',
    'o'    => 'output',
    's'    => 'script',
    'a'    => 'args'
);
for ($i=1;$i<$argc;++$i)
{
    if (preg_match('/^(-)-?([copisaf])[^=]*=(.*)$/', $argv[$i], $matches))
    {
        if ($matches[2] === 'f')
        {
            if (file_exists($matches[3]))
            {
                $params = json_decode(file_get_contents($matches[3]));
                break;
            }
        }
        if (isset($flags[$matches[2]]))
        {
            $params[$flags[$matches[2]]] = $matches[2] === 'c' ? (int) $matches[3] : $matches[3];
        }
    }
}
$descriptors = array(
    0   => array(
        'pipe',
        'r'
    ),
    1   => array(
        'pipe',
        'w',
    ),
    2   => array(
        'pipe',
        'w'
    )
);
if ($params['output'])
{
    $params['output'] = $params['output']{0} === '/' ? $params['output'] : $params['path'].$params['output'];
    $descriptors[1] = array(
        'file',
        'a'
    );
}
$params['script'] = $params['script']{0} === '/' ? $params['script'] : $params['path'].$params['script'];
$cmd .= $params['script'].' '.$params['args'];

$successCount = 0;
for ($i=$params['count'] -1;$i!=0;--$i)
{
    $process = proc_open(
        $cmd,
        $descriptors,
        $pipes,
        $params['path'],
        $params['env']
    );
    if (!is_resource($process))
    {
        sprintf(
            STDERR,
            'Failed to start process "%s", in path %s\nSuccess count: %s',
            $cmd,
            $params['path'],
            $successCount
        );
        exit(1);
    }
    do {
        usleep(200);
        $status = proc_get_status($process);
    } while ($status['running'] && !($err = fread($pipes[2], 4)));
    if ($status['running'])
        $err .= stream_get_contents($pipes[2]);
    else
        $err = 'No errors, process finished (run #'. ++$successCount.')';
    array_map( 'fclose', $pipes);
    proc_close($process);
    echo $err, PHP_EOL;
    if ($status['running'])
        exit(1);
}
exit(0);
