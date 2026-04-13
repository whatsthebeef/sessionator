aws s3 sync dist/pocketlab-web/browser s3://app$([[ $PL_ENV == 'prod' ]] && echo '' || echo '-'$PL_ENV).thepocketlab.com --delete
aws cloudfront create-invalidation --distribution-id  $(([[ $PL_ENV == 'prod' ]] && echo 'E1YVWGW9HAU6U3') || ([[ $PL_ENV == 'staging' ]] && echo 'E1F31J5RH5JC1H') || ([[ $PL_ENV == 'int' ]] && echo 'E3N5FMYD2N5N6E')  || echo 'E3A24WSPYITC36') --paths '/*'
