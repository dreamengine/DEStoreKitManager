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
@interface DEStoreKitManager ()

@property (nonatomic, retain) NSMutableSet *productsFetchHandlers;
@property (nonatomic, retain) NSMutableSet *transactionHandlers;

-(void) addProductsToCache:(NSSet *)products;

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler;

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler;

@end










//**************************************************
//
// Products Fetch Handler
//
//**************************************************
#pragma mark - Products Fetch Handler

@interface DEStoreKitProductsFetchHandler : NSObject <SKProductsRequestDelegate>

@property (nonatomic) BOOL shouldCache;
@property (nonatomic, strong) NSSet *productIdentifiers;
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
    self.request = [[SKProductsRequest alloc] initWithProductIdentifiers:self.productIdentifiers];
    self.request.delegate = self;
    [self.request start];
}

- (void)productsRequest: (SKProductsRequest *)request
     didReceiveResponse: (SKProductsResponse *)response {
    NSSet *fetchedProducts = [NSSet setWithArray:response.products];
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
// Store Kit Manager
//
//**************************************************
#pragma mark - Store Kit Manager


@implementation DEStoreKitManager

@synthesize cachedProducts = cachedProducts_;
@synthesize productsFetchHandlers = productsFetchHandlers_;
@synthesize transactionHandlers = transactionHandlers_;



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
        cachedProducts_ = [NSSet new];

        self.productsFetchHandlers = [NSMutableSet set];
        self.transactionHandlers = [NSMutableSet set];
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

-(void) addProductsToCache:(NSSet *)products {
    NSSet *newCache = [self.cachedProducts setByAddingObjectsFromSet:products];
    cachedProducts_ = newCache;
}

-(void) removeProductsFromCache:(NSSet *)products {
    NSMutableSet *mutableCache = [NSMutableSet setWithSet:cachedProducts_];
    for (id product in products) {
        [mutableCache removeObject:product];
    }

    NSSet *newCache = [NSSet setWithSet:mutableCache];
    cachedProducts_ = newCache;
}

-(void) removeAllProductsFromCache {
    NSSet *newCache = [NSSet set];
    cachedProducts_ = newCache;
}


#pragma mark - Handlers

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler {
    [self.productsFetchHandlers removeObject:handler];  // this should decrease the retain count to 0 for the handler, thereby deallocing it
}

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler {
    [self.transactionHandlers removeObject:handler];
}


#pragma mark - Fetch Products

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate {
    [self fetchProductsWithIdentifiers: productIdentifiers
                              delegate: delegate
                           cacheResult: YES];
}

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
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

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                           onSuccess: (DEStoreKitProductsFetchSuccessBlock)success
                           onFailure: (DEStoreKitErrorBlock)failure {
    [self fetchProductsWithIdentifiers: productIdentifiers
                             onSuccess: success
                             onFailure: failure
                           cacheResult: YES];
}

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
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

-(void) transaction: (SKPaymentTransaction *)transaction
          didVerify: (BOOL)isValid {
    for (DEStoreKitTransactionHandler *handler in self.transactionHandlers) {
        if ([handler.payment isEqual:transaction.payment]) {
            [handler transaction: transaction
                     wasVerified: isValid];
            break;
        }
    }
}

@end
