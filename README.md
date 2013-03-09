# DEStoreKitManager
[http://github.com/dreamengineinteractive/DEStoreKitManager](http://github.com/dreamengineinteractive/DEStoreKitManager)

## What It Does

`DEStoreKitManager` is an MIT-licensed library that streamlines iOS In-App Purchases. It automatically takes care of the IAP boilerplate for you so you can concentrate on shipping and on making better products.

`DEStoreKitManager` is designed to be as flexible and lightweight to use as possible. You can use either blocks or delegates to fetch products from the App Store and carry out purchase transactions.

With blocks, managing StoreKit interactions has never been easier: you can have all your logic encapsulated in one section of code.

If you want to use delegates instead, `DEStoreKitManager` is architectured to make that easier too. For each product fetch or purchase, you can have a different delegate, and each delegate will be notified only about the fetch/purchase it initiated. You can have multiple delegates simultaneously doing any number of fetches and/or purchases without worry of sorting out which delegate is responsible for what.

By default, `DEStoreKitManager` also automatically caches the products you've received in memory, so you don't need to keep track of the individual `SKProducts`. If you do want to keep track of the products yourself, `DEStoreKitManager` allows for that as well.

## Blocks

### Product Fetching

To fetch a list of products, simply call `fetchProductsWithIdentifiers:onSuccess:onFailure:` in `DEStoreKitManager`. Your blocks will be called when the fetch completes or fails.

If you'd rather not use the automatic product caching feature, then you can use `fetchProductsWithIdentifiers:onSuccess:onFailure:cacheResult:` and pass `NO` for the last parameter. Then, when the product is to be purchased, simply use `purchaseProduct:onSuccess:onRestore:onFailure:onCancel:onVerify:` instead of `purchaseProductWithIdentifier:…`.

#### Example


	NSSet *productIdentifiers = [NSSet setWithObjects:@"com.example.removeads", @"com.example.upgrade", nil];

	[[DEStoreKitManager sharedManager] fetchProductsWithIdentifiers:productIdentifiers
		onSuccess: ^(NSArray *products, NSArray *invalidIdentifiers) {
			// handle successful product fetch
		}
		onFailure: ^(NSError *error) {
			// handle failure here.
		}
	];


### Product Purchasing (Transactions)

To purchase a product, simply use `purchaseProduct:onSuccess:onRestore:onFailure:onCancel:onVerify:`. If you are utilizing automatic product caching, then you can use `purchaseProductWithIdentifier:…` instead, which will return `YES` if it has a matching `SKProduct` in the cache and will initiate the transaction; otherwise, it will return `NO`, meaning that there was no cached product matching the provided identifier and therefore no transaction will occur.

`DEStoreKitManager` does not force you to adhere to a specific receipt verification procedure. Instead, the `verify` block is responsible for verification. Once your procedure has determined the validity of the receipt/transaction, you are responsible for calling `transaction:didVerify:` in `DEStoreKitManager`, which will then call your `success`, `restore`, or `failure` block depending on the what was passed into `DEStoreKitManager` as well as the state of the transaction itself.

`DEStoreKitManager` has built-in conveniences if you choose to pass in `nil` for certain blocks:

* If you pass in `nil` for your `verify` block, then `DEStoreKitManager` will not attempt to verify your receipt and will instead automatically complete the transaction.
* If you pass in `nil` for your `restore` block, then `DEStoreKitManager` will instead call your `success` block if the transaction should be restored.
* If you pass in `nil` for your `cancel` block, then `DEStoreKitManager` will instead call your `failure` block if the transaction was canceled.


#### Example

	BOOL willAttemptPurchase = [[DEStoreKitManager sharedManager] purchaseProductWithIdentifier: @"com.example.removeads"
	onSuccess: ^(SKPaymentTransaction *transaction) {
		// record the purchase here
	}
	onRestore: ^(SKPaymentTransaction *transaction) {
		// record the purchase here
	}
	onFailure: ^(SKPaymentTransaction *transaction) {
		// handle failure here
	}
	onCancel: ^(SKPaymentTransaction *transaction) {
		// handle cancel here
	}
	onVerify: ^(SKPaymentTransaction *transaction) {
		// verify the receipt here. when validity has been determined, make sure to call [[DEStoreKitManager sharedManager] transaction:transaction didVerify:isValid];
	}];



## Delegate Pattern

### Product Fetching

To fetch a list of products, simply have your delegate object adhere to the `DEStoreKitManagerDelegate` protocol and have the following callbacks implemented: `productsFetched:invalidIdentifiers:` and `productsFetchedFailed:`. Then, just call `fetchProductsWithIdentifier:delegate:` and wait for the callbacks to be messaged.

You can have as many simultaneous product fetches going as you'd like (though we recommend doing fewer fetches with more product identifiers in each fetch).

If you'd rather not use the automatic product caching, then you can use `fetchProductsWithIdentifier:delegate:cacheResult:` and pass `NO` for the last parameter. Then, when the product is to be purchased, simply use `purchaseProduct:delegate:` instead of `purchaseProductWithIdentifier:delegate:`.

#### Example

    #import "DEStoreKitManager.h"
    
    @interface MyViewController: UIViewController <DEStoreKitManagerDelegate>
    
    …
    
    @implementation MyViewController

    …

	-(void) viewDidLoad {
		[super viewDidLoad];

		[self fetchProducts];
	}

	-(void) fetchProducts {
		NSSet *productIdentifiers = [NSSet setWithObjects:@"com.example.removeads", @"com.example.upgrade", nil];
	
			[[DEStoreKitManager sharedManager] fetchProductsWithIdentifiers: productIdentifiers
																   delegate: self];	
	}
    
    -(void)productsFetched: (NSArray *)products
     	invalidIdentifiers: (NSArray *)invalidIdentifiers {
     	// If you specified DEStoreKitManager not to cache, then you are responsible for holding onto the products array.
     	// Otherwise, you can record that the products have been fetched here.
    }

	-(void) productsFetchFailed:(NSError *)error {
		// Handle the failure here
	}

    …


### Product Purchasing (Transactions)

To purchase a product, have your delegate implement the following methods: `transactionSucceeded:`, `transactionRestored:` (optional), `transactionFailed:`, and `transactionCanceled:` (optional). Then, use `DEStoreKitManager` to initiate the transaction. Just as with the product fetching, you can have as many simultaneous transaction as you want.

If `transactionRestored:` is not implemented in your delegate, then a restored purchase will be sent instead to `transactionSucceeded:`. Similarly, if `transactionCanceled:` is not implemented, then `transacitonFailed:` will be called instead if the user cancels the purchase.

If you are relying on `DEStoreKitManager` to cache your products, you can call `purchaseProductWithProductIdentifier:delegate:` to start the purchase procedure. If the product has not been fetched and cached into `DEStoreKitManager`, then this will return `NO`, meaning that the purchase will not be attempted. Otherwise, if `DEStoreKitManager` finds an SKProduct with matching product identifier, this method will return `YES`, meaning that a purchase transaction has begun.

If you are keeping track of SKProducts outside of `DEStoreKitManager`, then you should instead use `purchaseProduct:delegate:`, which will immediately begin a purchase transaction.

#### Example

    -(IBAction)buyButtonTapped:(id)sender {
    	[[DEStoreKitManager sharedManager] purchaseProductWithProductIdentifier:@"com.example.removeads" delegate:self];	
		[self.activityIndicator startAnimating];
    }

	-(void) transactionSucceeded:(SKPaymentTransaction *)transaction {
		// record the purchase here
	}

	-(void) transactionFailed:(SKPaymentTransaction *)transaction {
		// handle failed transaction here
	}



### Transaction Receipt Verification

`DEStoreKitManager` does not force you to adhere to a specific receipt verification procedure. In fact, though we do recommend receipt validation, `DEStoreKitManager` does not require any validation whatsoever.

Instead, you can optionally choose to verify a receipt by having your delegate implement the `transactionNeedsVerification:` method. Your delegate will then be responsible for determining if the transaction is valid.

After the validity has been determined, the delegate is then responsible for notifying the `DEStoreKitManager` by calling `transaction:didVerify:` and letting it know whether or not the receipt was valid.

Once this occurs, `DEStoreKitManager` will then proceed to call either `transactionSucceeded:/transactionRestored:` if the receipt was valid or `transactionFailed:` if the receipt was invalid.
