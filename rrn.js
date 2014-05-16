/**
 * Basic RRN (SSN) number checker/generator/validator
 */

var RRMod = (function()
{
    var module = {},
    str2date = function(str)
    {
        var parts = str.split(/[^\d]+/);
        if (parts.length != 3)
            return false;
        if (parts[2].length === 4)
            parts = parts.reverse;//reverse dd mm YYYY
        //assume YYYY-mm-dd
        if (parts[0].length === 4)
            return new Date(parts.join('/'));//works fine
        //all parts are 2 long?
        if (+(parts[0]) > 12)
            parts = parts.reverse();
        return new Date(parts.join('-'));
    },
    randMod = function (mod, max, odd)
    {
        var r;
        mod = mod || 997;
        max = max || 1000;
        odd = odd || 1;
        do
        {
            r = Math.round(Math.random()*max + 1)%mod
        } while (r%2 !== odd);
        return r || 998;//max even is 998
    },
    bd2rr = function(date, sex)
    {
        var year, month, day, count;
        if (!date instanceof Date)
            date = str2date(date);
        //day-count:
        sex = sex.toLowerCase() === 'f' ? 0 : 1;
        count = ('000' + randMod(997, 1000, sex)).substr(-3);
        year = ('00' + (date.getFullYear()%100)).substr(-2);//get last 2 digits
        month = ('00' + (date.getMonth()+1)).substr(-2);//months are zero indexed
        day = ('00' + date.getDate()).substr(-2);
        return year+month+day+count;
    },
    rrn = function(rrnString)
    {
        var num, base = (rrnString.replace(/[^0-9]/g,'')).substr(0,9)
        if (base.length != 9)
            return false;
        num = parseInt(base, 10);//use parseInt to avoid octals in case of leading zeroes
        num = ('00' + (97 - (num%97))).substr(-2);
        return base.replace(/^(\d{2})(\d{2})(\d{2})(\d{3})/,'$1.$2.$3-$4-' + num);
    };
    module.addValidator = rrn;
    module.date2baseRR = bd2rr;
    module.validate = function (nr)
    {
        return (nr.substr(-3) === rrn(nr).substr(-3));
    };
    module.generateRandom = function(minAge, sex)
    {
        var date = new Date();
        sex = (sex || 'm').toLowerCase() === 'f' ? 'f' : 'm';
        minAge = minAge || 0;
        if (minAge)
        {//assume max age is 100
            minAge = (minAge+Math.floor(Math.random()*100))%100 || minAge;
        }
        date.setFullYear(date.getFullYear() - minAge);
        date.setMonth(Math.round(Math.random()*100)%12);
        date.setDate(Math.round(Math.random()*100)%32);
        return rrn(bd2rr(date, sex));
    };
    module.generateRR = function(d, s, full)
    {
        full = typeof full === 'undefined' ? true : full;
        if (full)
            return rrn(bd2rr(d,s));
        return bd2rr(d,s);
    };
    return module;
}());


/*console.log(RRMod.generateRandom(18));
console.log(RRMod.generateRR(new Date(), 'f'));
console.log(RRMod.generateRR(new Date(), 'm', false));
console.log(RRMod.addValidator('99.01.01-009-??'));*/
