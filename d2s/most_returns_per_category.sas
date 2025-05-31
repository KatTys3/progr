ods listing close;
ods html5 (id=saspy_internal) options(bitmap_mode='inline') device=svg style=HTMLBlue;
ods graphics on / outputfmt=png;

data ReturnsWithCategory;
    set AdventureWorks2022.Sales.SalesOrderHeader (keep=SalesOrderID OrderDate Status);
    by SalesOrderID;

    if _n_ = 1 then do;
        declare hash detail(dataset: "AdventureWorks2022.Sales.SalesOrderDetail");
        detail.defineKey('SalesOrderID');
        detail.defineData('ProductID', 'OrderQty', 'UnitPrice');
        detail.defineDone();

        /* Hash dla tabeli Product (podkategoria) */
        declare hash prod(dataset: "AdventureWorks2022.Production.Product (keep=ProductID ProductSubcategoryID)");
        prod.defineKey('ProductID');
        prod.defineData('ProductSubcategoryID');
        prod.defineDone();

        declare hash subs(dataset: "AdventureWorks2022.Production.ProductSubcategory (keep=ProductSubcategoryID ProductCategoryID)");
        subs.defineKey('ProductSubcategoryID');
        subs.defineData('ProductCategoryID');
        subs.defineDone();

        declare hash cat(dataset: "AdventureWorks2022.Production.ProductCategory (keep=ProductCategoryID Name)");
        cat.defineKey('ProductCategoryID');
        cat.defineData('Name');
        cat.defineDone();
    end;

    if Status = 4 then do;
        if detail.find() = 0 then do;
            if prod.find() = 0 then do;
                if subs.find() = 0 then do;
                    if cat.find() = 0 then do;
                        ReturnValue = OrderQty * UnitPrice;
                        Category = Name;
                        Year = year(OrderDate);
                        Month = month(OrderDate);
                        MonthName = put(OrderDate, monname.);
                        output;
                    end;
                end;
            end;
        end;
    end;
run;

proc summary data=ReturnsWithCategory nway;
    class Category;
    var ReturnValue;
    output out=ReturnValueByCategory (drop=_TYPE_ _FREQ_)
        sum=TotalReturnValue;
run;

data ReturnValueByCategory;
    set ReturnValueByCategory;
    format TotalReturnValue dollar12.2;
run;

proc sort data=ReturnValueByCategory;
    by Category;
run;

proc sgplot data=ReturnValueByCategory;
    vbar Category / response=TotalReturnValue datalabel;
    xaxis label="Kategoria produktów";
    yaxis label="Wartość zwróconych produktów (USD)";
    title  "Wskaźnik zwrotów wg kategorii produktów";
run;

ods html5 (id=saspy_internal) close;
ods listing;
