ods listing close;
ods html5 (id=saspy_internal) options(bitmap_mode='inline') device=svg style=HTMLBlue;
ods graphics on / outputfmt=png;

/* --------------------------------------------------------------------------- */
/*  Data Step: zbudowanie hash’y i wyliczenie wskaźnika InventoryDays bez        */
/*  tworzenia dodatkowych tabel w WORK                                            */
/* --------------------------------------------------------------------------- */
data Work.InventoryWithDetails;
    /* Zmienna _N_ kontroluje pierwszą iterację; klucze i dane transientnie w hash’ach */
    if _N_ = 1 then do;
        /* 2.1. Hash z danymi o stanach magazynowych (ADVworks.ProductInventory) */
        declare hash hInv();
        hInv.defineKey('ProductID');              /* Klucz: ProductID */
        hInv.defineData('TotalInventory');        /* Dane: TotalInventory (będzie sumą Quantity) */
        hInv.defineDone();                        /* Zakończenie definicji obiektu hInv */

        /* 2.2. Agregacja stanów magazynowych do hash hInv */
        do until(eofInv);
            set ADVworks.ProductInventory(keep=ProductID Quantity) end=eofInv;
            /* Jeżeli wpis już istnieje w hInv, dodajemy Quantity do istniejącej wartości */
            if hInv.find(key:ProductID)=0 then do;
                TotalInventory + Quantity;       /* Użycie łączenia do sumy (suma akumulatora) */
                hInv.replace();                   /* Zastępujemy zaktualizowaną wartość TotalInventory */
            end;
            else do;
                TotalInventory = Quantity;        /* Nowy wpis, inicjalizujemy sumę od Quantity */
                hInv.add();                       /* Dodajemy nowy klucz i dane do hash’a */
            end;
            call missing(TotalInventory);        /* Czyścimy zmienną przed kolejną iteracją */
        end;

        /* 2.3. Hash do nagłówków zamówień (ADVworks.SalesOrderHeader) – potrzebny do pobrania OrderDate */
        declare hash hHeader(dataset:"ADVworks.SalesOrderHeader(keep=SalesOrderID OrderDate)");
        hHeader.defineKey('SalesOrderID');         /* Klucz: SalesOrderID */
        hHeader.defineData('OrderDate');           /* Dane: OrderDate */
        hHeader.defineDone();                      /* Zakończenie definicji hash hHeader */

        /* 2.4. Hash do agregacji sprzedaży per produkt, rok, miesiąc */
        declare hash hSales();
        hSales.defineKey('ProductID','Year','Month'); /* Klucz: ProductID + Year + Month */
        hSales.defineData('TotalSales');             /* Dane: TotalSales (akumulator sprzedaży) */
        hSales.defineDone();                         /* Zakończenie definicji hash hSales */

        /* 2.5. Agregacja sprzedaży: czytamy SalesOrderDetail i pobieramy datę z hHeader */
        do until(eofDet);
            set ADVworks.SalesOrderDetail(keep=SalesOrderID ProductID OrderQty) end=eofDet;
            /* Z tablicy hHeader pobieramy OrderDate wg SalesOrderID */
            if hHeader.find(key:SalesOrderID)=0 then do;
                Year  = year(OrderDate);           /* Rok sprzedaży */
                Month = month(OrderDate);          /* Miesiąc sprzedaży */
                /* Jeżeli wpis istnieje, sumujemy OrderQty do TotalSales */
                if hSales.find(key:ProductID, key:Year, key:Month)=0 then do;
                    TotalSales + OrderQty;        /* Akumulator: dodajemy bieżącą ilość */
                    hSales.replace();             /* Zastępujemy wartość w hash’u */
                end;
                else do;
                    TotalSales = OrderQty;        /* Nowy wpis: wartość początkowa = OrderQty */
                    hSales.add();                 /* Dodajemy nową kombinację kluczy do hash’u */
                end;
            end;
            call missing(TotalSales, Year, Month, OrderDate); /* Czyścimy zmienne pomocnicze */
        end;
        call missing(SalesOrderID, ProductID, OrderQty);     /* Czyścimy wejściowe zmienne */
    end;

    /* 2.6. Iteracja po hash hSales, wyliczenie InventoryDays i wypisanie wierszy wyjściowych */
    /*     Uwaga: iterator musi być zadeklarowany po zakończonym ładowaniu hash’y, a przed pierwszą wywołaniem当迭代 */
    if _N_ = 1 then do;
        declare hiter iter("hSales");   /* Inicjuj iterator dla hash hSales */
    end;

    /* Zmienna rc posłuży do kontroli pętli po hash */
    rc = iter.first();                 /* Pobieramy pierwszy klucz i dane z hSales (0 jeśli istnieje) */
    do while(rc = 0);
        /* Teraz ProductID, Year, Month, TotalSales są wczytane z wpisu hSales */
        /* Musimy pobrać TotalInventory z hInv dla tego ProductID */
        if hInv.find(key:ProductID)=0 and TotalSales > 0 then do;
            /* Obliczenie dni w miesiącu */
            DaysInMonth   = day(intnx('month', mdy(Month, 1, Year), 0, 'end')); /* Liczba dni w danym miesiącu */
            /* Wzór na InventoryDays */
            InventoryDays = (TotalInventory / TotalSales) * DaysInMonth;       /* DIO (Days Inventory Outstanding) adaptowane do danych ilościowych */
            /* Pomoćnicza zmienna datowa do wykresu: pierwszy dzień miesiąca */
            PeriodStart   = mdy(Month, 1, Year);
            format PeriodStart monyy7.; /* Format "MmmYYYY" np. "Sty2025" */

            output; /* Zapis wiersza do zbioru InventoryWithDetails */
        end;

        /* Przechodzimy do kolejnej pary kluczy w hSales */
        rc = iter.next();
    end;

    /* Musimy zatrzymać przetwarzanie DATA Step, aby uniknąć próby czytania z WORK.MonthlySales */
    stop;
    drop rc;  /* Usuwamy zmienną pomocniczą */
run;
