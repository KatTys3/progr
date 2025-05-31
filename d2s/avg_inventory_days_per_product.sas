ods listing close;
ods html5 (id=saspy_internal) options(bitmap_mode='inline') device=svg style=HTMLBlue;
ods graphics on / outputfmt=png;

data InventoryWithDetails;
    set MonthlySales (keep=ProductID Year Month TotalSales);
    by ProductID Year Month;

    if _N_ = 1 then do;
        declare hash hInv(dataset: "ProdInventory");
        hInv.defineKey('ProductID');
        hInv.defineData('TotalInventory');
        hInv.defineDone();

        declare hash hSales(dataset: "MonthlySales");
        hSales.defineKey('ProductID', 'Year', 'Month');
        hSales.defineData('TotalSales');
        hSales.defineDone();
    end;

    TotalInventory = .;
    rcInv = hInv.find(key: ProductID);

    rcSales = hSales.find(key: ProductID, key: Year, key: Month);

    if rcInv = 0 and rcSales = 0 and TotalSales > 0 then do;
        DaysInMonth = day(intnx('month', mdy(Month, 1, Year), 0, 'end'));
        InventoryDays = (TotalInventory / TotalSales) * DaysInMonth;
        PeriodStart = mdy(Month, 1, Year);
        output;
    end;

    drop rcInv rcSales;
run;
