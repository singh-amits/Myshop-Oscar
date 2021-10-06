from rest_framework.pagination import PageNumberPagination

class TotalPageNumberPagination(PageNumberPagination):
    page_size = 100