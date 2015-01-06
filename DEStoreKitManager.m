//
//  DEStoreKitManager.m
//  DEStoreKitManager
//
//  Created by Jeremy Flores on 11/19/12.
//
//  Copyright (c) 2012 Dream Engine Interactive, Inc. ( http://dreamengineinteractive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "DEStoreKitManager.h"



//**************************************************
//
// SKProduct category methods
//
//**************************************************
@implementation SKProduct (DEStoreKitManager)

-(NSString *) localizedPrice {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:self.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:self.price];
    return formattedString;
}

@end










//**************************************************
//
// Store Kit Manager private methods
//
//**************************************************
#pragma mark - Store Kit Manager private methods

@class DEStoreKitProductsFetchHandler;
@class DEStoreKitTransactionHandler;
@class DEStoreKitRestorationHandler;
@interface DEStoreKitManager ()

@property (nonatomic, strong) NSMutableArray *productsFetchHandlers;
@property (nonatomic, strong) NSMutableArray *transactionHandlers;
@property (nonatomic, strong) DEStoreKitRestorationHandler *restorationHandler;

-(void) addProductsToCache:(NSArray *)products;

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler;

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler;

-(void) restorationHandlerDidFinish:(DEStoreKitRestorationHandler *)handler;

@end










//**************************************************
//
// Products Fetch Handler
//
//**************************************************
#pragma mark - Products Fetch Handler

@interface DEStoreKitProductsFetchHandler : NSObject <SKProductsRequestDelegate>

@property (nonatomic) BOOL shouldCache;
@property (nonatomic, strong) NSArray *productIdentifiers;
@property (nonatomic, weak) DEStoreKitManager *storeKitManager;
@property (nonatomic, weak) id<DEStoreKitManagerDelegate> delegate;

@property (nonatomic, copy) DEStoreKitProductsFetchSuccessBlock successBlock;
@property (nonatomic, copy) DEStoreKitErrorBlock failureBlock;

@property (nonatomic, strong) SKProductsRequest *request;

-(void) fetch;

@end


@implementation DEStoreKitProductsFetchHandler

@synthesize shouldCache = shouldCache_;
@synthesize productIdentifiers = productIdentifiers_;
@synthesize storeKitManager = storeKitManager_;
@synthesize delegate = delegate_;

@synthesize successBlock = successBlock_;
@synthesize failureBlock = failureBlock_;

@synthesize request = request_;


-(void) fetch {
    self.request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:self.productIdentifiers]];
    self.request.delegate = self;
    [self.request start];
}

- (void)productsRequest: (SKProductsRequest *)request
     didReceiveResponse: (SKProductsResponse *)response {
    NSArray *fetchedProducts = response.products;
    if (self.shouldCache) {
        [self.storeKitManager addProductsToCache:fetchedProducts];
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(productsFetched:invalidIdentifiers:)]) {
        [self.delegate productsFetched: response.products
                    invalidIdentifiers: response.invalidProductIdentifiers];
    }
    else if (self.successBlock) {
        self.successBlock(response.products, response.invalidProductIdentifiers);
    }

    self.request.delegate = nil;
    [self.request cancel];
    [self.storeKitManager performSelector: @selector(productsFetchHandlerDidFinish:)
                               withObject: self
                               afterDelay: 2.f];    // need to perform after delay because, in iOS 6, SKProductsRequest erroneously keeps a record of the delegate and attempts to call it.
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(productsFetchFailed:)]) {
        [self.delegate productsFetchFailed:error];
    }
    else if (self.failureBlock) {
        self.failureBlock(error);
    }

    self.request.delegate = nil;
    [self.request cancel];
    [self.storeKitManager productsFetchHandlerDidFinish:self];
}

@end










//**************************************************
//
// Transaction Handler
//
//**************************************************
#pragma mark - Transaction Handler

@interface DEStoreKitTransactionHandler : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, strong) SKProduct *product;
@property (nonatomic, weak) DEStoreKitManager *storeKitManager;
@property (nonatomic, weak) id<DEStoreKitManagerDelegate> delegate;

@property (nonatomic, copy) DEStoreKitTransactionBlock successBlock;
@property (nonatomic, copy) DEStoreKitTransactionBlock restoreBlock;
@property (nonatomic, copy) DEStoreKitTransactionBlock failureBlock;
@property (nonatomic, copy) DEStoreKitTransactionBlock cancelBlock;
@property (nonatomic, copy) DEStoreKitTransactionBlock verifyBlock;

@property (nonatomic, strong) SKPayment *payment;

-(void) purchase;

-(void) transaction:(SKPaymentTransaction *)transaction
        wasVerified:(BOOL)isValid;

@end


@interface DEStoreKitTransactionHandler ()

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful;

@end


@implementation DEStoreKitTransactionHandler

@synthesize product = product_;
@synthesize storeKitManager = storeKitManager_;
@synthesize delegate = delegate_;

@synthesize successBlock = successBlock_;
@synthesize restoreBlock = restoreBlock_;
@synthesize failureBlock = failureBlock_;
@synthesize cancelBlock = cancelBlock_;
@synthesize verifyBlock = verifyBlock_;

@synthesize payment = payment_;

-(void) purchase {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    self.payment = [SKPayment paymentWithProduct:self.product];

    [[SKPaymentQueue defaultQueue] addPayment:self.payment];
}

- (void)paymentQueue: (SKPaymentQueue *)queue
 updatedTransactions: (NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        if ([transaction.payment isEqual:self.payment]) {
            switch (transaction.transactionState) {
                case SKPaymentTransactionStatePurchased:
                case SKPaymentTransactionStateRestored:
                    if (self.delegate && [self.delegate respondsToSelector:@selector(transactionNeedsVerification:)]) {
                        [self.delegate transactionNeedsVerification:transaction];
                    }
                    else if (self.verifyBlock) {
                        self.verifyBlock(transaction);
                    }
                    else {
                        [self finishTransaction:transaction wasSuccessful:YES];
                    }
                    break;
                case SKPaymentTransactionStateFailed:
                    [self finishTransaction:transaction wasSuccessful:NO];
                    break;
                case SKPaymentTransactionStatePurchasing:
                default:
                    break;
            }
            break;
        }
    }
}

-(void) transaction: (SKPaymentTransaction *)transaction
        wasVerified: (BOOL)isValid {
    [self finishTransaction:transaction wasSuccessful:isValid];
}

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    if (wasSuccessful) {
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(transactionRestored:)]) {
                [self.delegate transactionRestored:transaction];
            }
            else if (self.delegate && [self.delegate respondsToSelector:@selector(transactionSucceeded:)]) {
                [self.delegate transactionSucceeded:transaction];
            }
            else if (self.restoreBlock) {
                self.restoreBlock(transaction);
            }
            else if (self.successBlock) {
                self.successBlock(transaction);
            }
        }
        else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(transactionSucceeded:)]) {
                [self.delegate transactionSucceeded:transaction];
            }
            else if (self.successBlock) {
                self.successBlock(transaction);
            }
        }
    }
    else {
        if (transaction.error.code == SKErrorPaymentCancelled) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(transactionCanceled:)]) {
                [self.delegate transactionCanceled:transaction];
            }
            else if (self.delegate && [self.delegate respondsToSelector:@selector(transactionFailed:)]) {
                [self.delegate transactionFailed:transaction];
            }
            else if (self.cancelBlock) {
                self.cancelBlock(transaction);
            }
            else if (self.failureBlock) {
                self.failureBlock(transaction);
            }
        }
        else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(transactionFailed:)]) {
                [self.delegate transactionFailed:transaction];
            }
            else if (self.failureBlock) {
                self.failureBlock(transaction);
            }
        }
    }

    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [self.storeKitManager transactionHandlerDidFinish:self];
}


@end





//**************************************************
//
// Restoration Handler
//
//**************************************************
#pragma mark - Restoration Handler

typedef void (^DEStoreKitRestorationHandlerSuccessBlock)(NSArray *restoredTransactions, NSArray *failedTransactions);
typedef void (^DEStoreKitRestorationHandlerFailureBlock)(NSError *error);
typedef void (^DEStoreKitRestorationHandlerVerifyBlock)(NSArray *transactions);




@interface DEStoreKitRestorationHandler : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, weak) DEStoreKitManager *storeKitManager;
@property (nonatomic, weak) id<DEStoreKitManagerDelegate> delegate;

@property (nonatomic, strong) NSMutableArray *restoredTransactions;

@property (nonatomic, copy) DEStoreKitRestorationHandlerSuccessBlock successBlock;
@property (nonatomic, copy) DEStoreKitRestorationHandlerFailureBlock failureBlock;
@property (nonatomic, copy) DEStoreKitRestorationHandlerVerifyBlock verifyBlock;

-(void) restore;

-(void) transaction:(SKPaymentTransaction *)transaction
          didVerify:(BOOL)isValid;

@end



@interface DEStoreKitRestorationHandler ()

@property (nonatomic, strong) NSMutableArray *verifiedTransactions;
@property (nonatomic, strong) NSMutableArray *invalidTransactions;

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful;

-(void) transactionsDidFinish;

@end



@implementation DEStoreKitRestorationHandler

@synthesize storeKitManager = storeKitManager_;
@synthesize delegate = delegate_;

@synthesize restoredTransactions = restoredTransactions_;
@synthesize verifiedTransactions = verifiedTransactions_;
@synthesize invalidTransactions = invalidTransactions_;

@synthesize successBlock = successBlock_;
@synthesize failureBlock = failureBlock_;
@synthesize verifyBlock = verifyBlock_;

-(id) init {
    if (self=[super init]) {
        self.restoredTransactions = [NSMutableArray new];
        self.verifiedTransactions = [NSMutableArray new];
        self.invalidTransactions = [NSMutableArray new];
    }
    
    return self;
}

-(void) restore {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

/*
 AFAIK, there's no way for us to automatically know which transactions are from the restoreCompletedTransactions
 request and which come from addPayment:, so we need to manually determine which transactions should be processed
 by this handler. Therefore, we rely on the following assumptions:
 
 * -addPayment: requests are coming only from DEStoreKitTransactionHandler objects
 * -restoreCompletedTransaction requests are coming only from DEStoreKitRestorationHandler objects
 * There is at any time at most one DEStoreKitRestorationHandler object requesting -restoreCompletedTransaction
 
 Note that these requirements allow for simultaneous restoration and purchasing, but restrict the developer by
 tying the code to more exclusively utilize DEStoreKitManager (i.e. no outside requests to the SKPaymentQueue).
 */
-(void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored:
                [self.restoredTransactions addObject:transaction];
                break;
            default:
                [self finishTransaction:transaction
                          wasSuccessful:NO];
                break;
        }
        
    }
}


-(void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(restorationNeedsVerification:)]) {
        [self.delegate restorationNeedsVerification:self.restoredTransactions];
    }
    else if (self.verifyBlock) {
        self.verifyBlock(self.restoredTransactions);
    }
    else {
        for (SKPaymentTransaction *transaction in self.restoredTransactions) {
            [self finishTransaction:transaction wasSuccessful:YES];
        }
    }
    [self transactionsDidFinish];
}

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful {
    if (transaction != nil) {
        if (wasSuccessful) {
            [self.verifiedTransactions addObject:transaction];
        }
        else {
            [self.invalidTransactions addObject:transaction];
        }
        
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

-(void) transactionsDidFinish {
    if (self.delegate && [self.delegate respondsToSelector:@selector(restorationSucceeded:invalidTransactions:)]) {
        [self.delegate restorationSucceeded:self.verifiedTransactions invalidTransactions:self.invalidTransactions];
    }
    else if (self.successBlock) {
        self.successBlock(self.verifiedTransactions, self.invalidTransactions);
    }
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [self.storeKitManager restorationHandlerDidFinish:self];
}

-(void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(restorationFailed:)]) {
        [self.delegate restorationFailed:error];
    }
    else if (self.failureBlock) {
        self.failureBlock(error);
    }
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [self.storeKitManager restorationHandlerDidFinish:self];
}

-(void) transaction: (SKPaymentTransaction *)transaction
          didVerify: (BOOL)isValid {
    [self finishTransaction:transaction wasSuccessful:isValid];
}

@end




//**************************************************
//
// Store Kit Manager
//
//**************************************************
#pragma mark - Store Kit Manager


@implementation DEStoreKitManager

@synthesize cachedProducts = cachedProducts_;
@synthesize productsFetchHandlers = productsFetchHandlers_;
@synthesize transactionHandlers = transactionHandlers_;
@synthesize restorationHandler = restorationHandler_;


#pragma mark - Static method

+(id)sharedManager {
    static DEStoreKitManager *sharedManager = nil;

    if (!sharedManager) {
        sharedManager = [DEStoreKitManager new];
    }

    return sharedManager;
}


#pragma mark - Initialization

-(id) init {
    if (self=[super init]) {
        cachedProducts_ = [NSArray new];

        self.productsFetchHandlers = [NSMutableArray new];
        self.transactionHandlers = [NSMutableArray new];
    }

    return self;
}


#pragma mark - Can Make Purchases

- (BOOL)canMakePurchases {
    return [SKPaymentQueue canMakePayments];
}


#pragma mark - Cache

-(SKProduct *)cachedProductWithIdentifier:(NSString *)productIdentifier {
    for (SKProduct *product in self.cachedProducts) {
        if ([product.productIdentifier isEqualToString:productIdentifier]) {
            return product;
        }
    }
    return nil;
}

-(void) addProductsToCache:(NSArray *)products {
    cachedProducts_ = products;
}

-(void) removeProductsFromCache:(NSArray *)products {
    NSMutableArray *mutableCache = [cachedProducts_ mutableCopy];
    for (id product in products) {
        [mutableCache removeObject:product];
    }

    NSArray *newCache = [mutableCache copy];
    cachedProducts_ = newCache;
}

-(void) removeAllProductsFromCache {
    cachedProducts_ = [NSArray new];
}


#pragma mark - Handlers

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler {
    [self.productsFetchHandlers removeObject:handler];  // this should decrease the retain count to 0 for the handler, thereby deallocing it
}

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler {
    [self.transactionHandlers removeObject:handler];
}


-(void) restorationHandlerDidFinish:(DEStoreKitRestorationHandler *)handler {
    self.restorationHandler = nil;
}

#pragma mark - Fetch Products

-(void) fetchProductsWithIdentifiers: (NSArray *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate {
    [self fetchProductsWithIdentifiers: productIdentifiers
                              delegate: delegate
                           cacheResult: YES];
}

-(void) fetchProductsWithIdentifiers: (NSArray *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate
                         cacheResult: (BOOL)shouldCache {
    DEStoreKitProductsFetchHandler *handler = [DEStoreKitProductsFetchHandler new] ;
    handler.storeKitManager = self;
    handler.shouldCache = shouldCache;
    handler.productIdentifiers = productIdentifiers;
    handler.delegate = delegate;
    
    [self.productsFetchHandlers addObject:handler];

    [handler fetch];
}

-(void) fetchProductsWithIdentifiers: (NSArray *)productIdentifiers
                           onSuccess: (DEStoreKitProductsFetchSuccessBlock)success
                           onFailure: (DEStoreKitErrorBlock)failure {
    [self fetchProductsWithIdentifiers: productIdentifiers
                             onSuccess: success
                             onFailure: failure
                           cacheResult: YES];
}

-(void) fetchProductsWithIdentifiers: (NSArray *)productIdentifiers
                           onSuccess: (DEStoreKitProductsFetchSuccessBlock)success
                           onFailure: (DEStoreKitErrorBlock)failure
                         cacheResult: (BOOL)shouldCache {
    DEStoreKitProductsFetchHandler *handler = [DEStoreKitProductsFetchHandler new];

    handler.storeKitManager = self;
    handler.shouldCache = shouldCache;
    handler.productIdentifiers = productIdentifiers;
    handler.successBlock = success;
    handler.failureBlock = failure;

    [self.productsFetchHandlers addObject:handler];

    [handler fetch];
}


#pragma mark - Transaction

-(BOOL) purchaseProductWithIdentifier: (NSString *)productIdentifier
                             delegate: (id<DEStoreKitManagerDelegate>) delegate {
    for (SKProduct *product in self.cachedProducts) {
        if ([product.productIdentifier isEqualToString:productIdentifier]) {
            [self purchaseProduct: product
                         delegate: delegate];
            return YES;
            break;
        }
    }

    return NO;
}

-(void) purchaseProduct: (SKProduct *)product
               delegate: (id<DEStoreKitManagerDelegate>) delegate {
    DEStoreKitTransactionHandler *handler = [DEStoreKitTransactionHandler new];

    handler.storeKitManager = self;
    handler.product = product;
    handler.delegate = delegate;

    [self.transactionHandlers addObject:handler];

    [handler purchase];
}

-(BOOL) purchaseProductWithIdentifier: (NSString *)productIdentifier
                            onSuccess: (DEStoreKitTransactionBlock)success
                            onRestore: (DEStoreKitTransactionBlock)restore
                            onFailure: (DEStoreKitTransactionBlock)failure
                             onCancel: (DEStoreKitTransactionBlock)cancel
                             onVerify: (DEStoreKitTransactionBlock)verify {
    for (SKProduct *product in self.cachedProducts) {
        if ([product.productIdentifier isEqualToString:productIdentifier]) {
            [self purchaseProduct: product
                        onSuccess: success
                        onRestore: restore
                        onFailure: failure
                         onCancel: cancel
                         onVerify: verify];
            return YES;
            break;
        }
    }
    
    return NO;
}

-(void) purchaseProduct: (SKProduct *)product
              onSuccess: (DEStoreKitTransactionBlock)success
              onRestore: (DEStoreKitTransactionBlock)restore
              onFailure: (DEStoreKitTransactionBlock)failure
               onCancel: (DEStoreKitTransactionBlock)cancel
               onVerify: (DEStoreKitTransactionBlock)verify {
    DEStoreKitTransactionHandler *handler = [DEStoreKitTransactionHandler new];

    handler.storeKitManager = self;
    handler.product = product;
    handler.successBlock = success;
    handler.restoreBlock = restore;
    handler.failureBlock = failure;
    handler.cancelBlock = cancel;
    handler.verifyBlock = verify;

    [self.transactionHandlers addObject:handler];

    [handler purchase];
}

-(BOOL) restorePreviousPurchasesWithDelegate: (id<DEStoreKitManagerDelegate>)delegate {
    if (self.restorationHandler) {
        return NO;
    }
    
    self.restorationHandler = [DEStoreKitRestorationHandler new];
    
    self.restorationHandler.storeKitManager = self;
    self.restorationHandler.delegate = delegate;
    
    [self.restorationHandler restore];
    
    return YES;
}


-(BOOL) restorePreviousPurchasesOnSuccess: (void (^)(NSArray *verifiedTransactions, NSArray *failedTransactions))success
                                onFailure: (void (^)(NSError *error))failure
                                 onVerify: (void (^)(NSArray *transactions))verify {
    if (self.restorationHandler) {
        return NO;
    }
    
    self.restorationHandler = [DEStoreKitRestorationHandler new];
    
    self.restorationHandler.storeKitManager = self;
    self.restorationHandler.successBlock = success;
    self.restorationHandler.failureBlock = failure;
    self.restorationHandler.verifyBlock = verify;
    
    [self.restorationHandler restore];
    
    return YES;
}

-(void) transaction: (SKPaymentTransaction *)transaction
          didVerify: (BOOL)isValid {
    for (DEStoreKitTransactionHandler *handler in self.transactionHandlers) {
        if ([handler.payment isEqual:transaction.payment]) {
            [handler transaction: transaction
                     wasVerified: isValid];
            return;
        }
    }
    if (self.restorationHandler) {
        for (SKPaymentTransaction *restoredTransaction in self.restorationHandler.restoredTransactions) {
            if ([restoredTransaction isEqual:transaction]) {
                [self.restorationHandler transaction: transaction
                                           didVerify: isValid];
                return;
            }
        }
    }
}

@end
