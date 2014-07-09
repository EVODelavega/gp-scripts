/**
 * Basic RRN (SSN) number checker/generator/validator
 */

var RRMod = (function()
{
    var modMax = 1000,
    modBase = 997,
    checkBase = 97,
    module = {},
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
        mod = mod || modBase;
        max = max || modMax;
        odd = odd || 1;
        do
        {
            r = Math.round(Math.random()*max + 1)%mod
        } while (r%2 !== odd);
        return r || modMax + 1;//max even is 998
    },
    bd2rr = function(date, sex)
    {
        var year, month, day, count;
        if (!date instanceof Date)
            date = str2date(date);
        //day-count:
        sex = sex.toLowerCase() === 'f' ? 0 : 1;
        count = ('0000' + randMod(modBase, modMax, sex)).substr(-1*(''+modMax).length);
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
        num = ('0000' + (checkBase - (num%checkBase))).substr(-1 * (''+checkBase).length);
        return base.replace(/^(\d{2})(\d{2})(\d{2})(\d{3})/,'$1.$2.$3-$4-' + num);
    },
    usSsn = function()
    {
        var k,
            check,
            bases = [900,100,10000],
            groups =[
                (Math.round(Math.random()*1000)+111)%bases[0],
                (Math.round(Math.random()*100)+1)%bases[1],
                (Math.round(Math.random()*10000)+1)%bases[2]
        ];
        for (k=0;k<groups.length;++k)
            if (!groups[k])
                groups[k] = Math.round(Math.random()*bases[k]);
        while (groups[0] === 666 || groups[0] > 900)
            groups[0] = (Math.round(Math.random()*1000)+111)%900;
        if (groups[0] === 987 && groups[1] === 65)
            while(groups[2] > 4319 && groups[2] < 4330)
                groups[2] = (Math.round(Math.random()*10000)+1)%10000;
        //the Woolworth SSN: 078-05-1120
        if (groups[0] === 78 && groups[1] === 5 && groups[2] === 1120)
        {
            k = (Math.round(Math.random()*10))%3;
            check = groups[k];
            while (groups[k] === check)
                groups[k] = Math.round(Math.random()*bases[k]);
            //small chance, but dirty fix to avoid prohibited SSN's from being generated here.
            if (groups[k] === 666) groups[k]++;
            else if (groups[k] === 0) groups[k]++;
            else if (groups[k] === 65) groups[k]++;
        }
        for (k = 0;k<groups.length;++k)
            groups[k] = ('0000' + groups[k]).substr( k === 2 ? -4 : (k -3));
        return groups.join('-');
    };
    Object.defineProperties(module, {
        modMax: {
            set: function(max)
            {
                modMax = Math.abs(+(max) || modMax);
            },
            get: function()
            {
                return modMax;
            }
        },
        modBase: {
            set: function(newB)
            {
                modBase = +(newB) || modBase;
            },
            get: function()
            {
                return modBase;
            }
        },
        checkBase: {
            set: function(newCB)
            {
                checkBase = Math.abs(+(newCB) || checkBase);
            },
            get: function()
            {
                return checkBase;
            }
        },
        addValidator: {
            value: rrn,
            writable: false
        },
        date2baseRR: {
            value: bd2rr,
            writable: false
        },
        validate: {
            value: function (nr)
            {
                return (nr.substr(-3) === rrn(nr).substr(-3));
            },
            writable: false
        },
        generateRandom: {
            value: function(minAge, sex)
            {
                var date = new Date();
                sex = (sex || 'm').toLowerCase() === 'f' ? 'f' : 'm';
                minAge = minAge || 0;
                if (minAge)
                    minAge = (minAge+Math.floor(Math.random()*100))%100 || minAge;
                date.setFullYear(date.getFullYear() - minAge);
                date.setMonth(Math.round(Math.random()*100)%12);
                date.setDate(Math.round(Math.random()*100)%32);
                return rrn(bd2rr(date, sex));
            },
            writable: false
        },
        generateRR: {
            value: function(d, s, full)
            {
                full = typeof full === 'undefined' ? true : full;
                if (full)
                    return rrn(bd2rr(d,s));
                return bd2rr(d,s);
            },
            writable: false
        },
        generateUSSSN: {
            value: usSsn,
            writable: false
        }
    });
    return module;
}());

/*
console.log(RRMod.modBase);
console.log(RRMod.generateRandom(18));
console.log(RRMod.generateRR(new Date(), 'f'));
console.log(RRMod.generateRR(new Date(), 'm', false));
console.log(RRMod.addValidator('99.01.01-009-??'));
*/

