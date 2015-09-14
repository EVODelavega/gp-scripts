<?php
function fatalErrors($errno, $errstr, $errfile, $errline)
{
    if (E_RECOVERABLE_ERROR === $errno) {
        printf(
            'Catchable fatal error raised in %s:%d => %s "%s"%s',
            $errfile,
            $errline,
            PHP_EOL . PHP_EOL,
            $errstr,
            PHP_EOL
        );
        return true;
    }
    return false;
}

set_error_handler('fatalErrors');

trait EvilTrait
{
    /**
     * @var int
     */
    public $foobarCalls = 0;

    /**
     * @var int
     */
    public static $constructorCalls = 0;

    /**
     * final AND protected, even if you override it, you shouldn't be allowed to make it private!
     * @return string
     */
    final protected function getSomeString()
    {
        return 'This was returned by a protected method called getSomeString';
    }

    /**
     * Abstracts are useful to ensure certain methods exist, and have a particular signature
     */
    abstract protected function someAbstractMethod();
 
    /**
     * Be careful with method names like this, if the using class has the same name, it might turn into
     * an old-school constructor... remember: PHP4-style constructors emit E_DEPRECATED notices
     */
    public function foobar()
    {
        $this->foobarCalls++;
        //late static binding is allowed
        //what if the using class defines $constructorCalls to be an array, string, int, object...?
        static::$constructorCalls++;
    }

    /**
     * Method with a distinct signature, that does a very specific task
     *
     * @param bool $increment = true
     *
     * @return $this
     */
    public function someTraitSpecificMethod($increment = true)
    {
        if (!$increment) {
            $this->foobarCalls--;
        } else {
            $this->foobarCalls++;
        }
        return $this;
    }

    /**
     * Call method defined in this trait... or not...
     * In this example, this method will trigger an E_RECOVERABLE_ERROR
     *
     * @param bool $increment = true
     *
     * @return $this
     */
    public function testInsteadOf($increment = true)
    {
        return $this->someTraitSpecificMethod($increment);
    }
}
trait DevilsOwnTrait
{
    /**
     * Some random trait with conflicting methods AND different return type
     *
     * @param array $data
     *
     * @return array
     */
    public function someTraitSpecificMethod(array $data)
    {
        //added this because the error is being "handled"
        //Not doing this will trigger warning (invalid argument provided for foreach)
        if (!is_array($data))
            $data = [];
        foreach ($data as $k => $v) {
            if (is_numeric($v))
                $v *= 2;
            elseif (is_string($v))
                $v = strtolower($v);
            $data[$k] = $v;
        }
        return $data;
    }
}
class Foobar
{
    use EvilTrait, DevilsOwnTrait {
        //using an alias AND changing visibility, that may not be a good idea
        getSomeString as public iSeeYou;
        //insteadof DOES overwrite the method entirely, unlike aliasing
        DevilsOwnTrait::someTraitSpecificMethod insteadof EvilTrait;
    }
 
    /**
     * Abstract declares this method as protected, so only protected and public
     * should be allowed, this is private and breaks the LSP, I'd expect a fatal error
     */
    private function someAbstractMethod()
    {
        return 'This should not be allowed';
    }
 
    /**
     * We've implemented an abstract method in an illegal fashion
     * Let's check if we can call this contract-breaking implementation:
     */
    public function testAbstractImplementation()
    {
        return $this->someAbstractMethod();
    }
 
    /**
     * Note: using as <alias> merely creates an alternative name that accesses the same method
     * doesn't mean the original method-name is forgotten, $this->iSeeYou(); is public, but $this->getSomeString(); still works
     * It only means that you can call it by a different name, AND that its visibility
     * depends on the alias...
     */
    public function demonstrateAlias()
    {
        return $this->getSomeString();
    }
}

echo 'Foobar::$constructorCalls => ' . Foobar::$constructorCalls . PHP_EOL;

$x = new Foobar();

echo PHP_EOL . 'New instance created -> foobar called as constructor: Foobar::$constructorCalls now is ' . Foobar::$constructorCalls . PHP_EOL;

echo PHP_EOL . 'Dump foobarCalls property (note PHP4 constructors issue E_DEPRECATED notice): ' . PHP_EOL;
var_dump($x->foobarCalls);

echo PHP_EOL . 'PHP4-style constructor can be called as a standard method afterwards: ' . PHP_EOL;
$x->foobar();
var_dump($x->foobarCalls);

echo PHP_EOL . 'abstract protected function someAbstractMethod(); -> made private?! To hell with the LSP:' . PHP_EOL;
echo $x->testAbstractImplementation(), PHP_EOL;

echo PHP_EOL . 'final protected function getSomeString() made public with iSeeYou alias. Aliases do not care about visibility, or final, or anything else...' . PHP_EOL . $x->iSeeYou(), PHP_EOL;

echo PHP_EOL . 'Aliases do not rename methods: ' . PHP_EOL . $x->demonstrateAlias() . PHP_EOL;

echo PHP_EOL . 'Worst of all: insteadof mess: passing an array works' . PHP_EOL;
var_dump($x->someTraitSpecificMethod(range(1, 10)));
echo PHP_EOL . 'Calling the "other" definition of the method, even indirectly via the defining trait method does not work' . PHP_EOL
             . 'The first trait method is completely overridden by the second trait. In short: you can break a trait!' . PHP_EOL;
$x->testInsteadOf();
